#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE="$ROOT_DIR/settings.env"
BUILD_DIR="$ROOT_DIR/build/remote-desktop"
GUAC_HOME="$BUILD_DIR/guacamole-home"

# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/site_registry.sh"

require_var() {
  local v="$1"
  [[ -n "${!v:-}" ]] || { echo "Missing required variable: $v" >&2; exit 1; }
}

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  printf '%s' "$value"
}

[[ -f "$SETTINGS_FILE" ]] || { echo "Missing settings.env" >&2; exit 1; }
# shellcheck source=/dev/null
source "$SETTINGS_FILE"

: "${REMOTE_DESKTOP_WEB_ENABLED:?Missing REMOTE_DESKTOP_WEB_ENABLED}"

if [[ "$REMOTE_DESKTOP_WEB_ENABLED" != "true" ]]; then
  echo "REMOTE_DESKTOP_WEB_ENABLED is not 'true'. Skipping Safari remote desktop render."
  exit 0
fi

if [[ -z "${REMOTE_DESKTOP_WEB_HOSTNAME:-}" ]]; then
  populate_site_hostname "$ROOT_DIR" "pit-box-remote-desktop" REMOTE_DESKTOP_WEB_HOSTNAME
fi
if [[ -z "${REMOTE_DESKTOP_HOSTNAME:-}" ]]; then
  if registry_hostname="$(resolve_registry_hostname "$ROOT_DIR" "pit-box-rdp" 2>/dev/null)" && [[ -n "$registry_hostname" ]]; then
    REMOTE_DESKTOP_HOSTNAME="$registry_hostname"
    export REMOTE_DESKTOP_HOSTNAME
  fi
fi

for var in CADDY_CERTS_DIR REMOTE_DESKTOP_WEB_HOSTNAME REMOTE_DESKTOP_WEB_PORT REMOTE_DESKTOP_PORT WG_SERVER_TUNNEL_IP; do
  require_var "$var"
done

REMOTE_DESKTOP_BIND_ADDRESS="${REMOTE_DESKTOP_BIND_ADDRESS:-$WG_SERVER_TUNNEL_IP}"
REMOTE_DESKTOP_GUACAMOLE_IMAGE="${REMOTE_DESKTOP_GUACAMOLE_IMAGE:-docker.io/guacamole/guacamole:1.6.0}"
REMOTE_DESKTOP_GUACD_IMAGE="${REMOTE_DESKTOP_GUACD_IMAGE:-docker.io/guacamole/guacd:1.6.0}"

credential_exports="$(
  "$ROOT_DIR/scripts/resolve_remote_desktop_password.py" \
    --entry "${REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_ENTRY:-}" \
    --profile "${REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_PROFILE:-}" \
    --env-file "${REMOTE_DESKTOP_WEB_AUTO_PASS_ENV_FILE:-}" \
    --user "${REMOTE_DESKTOP_WEB_USER:-}" \
    --fallback-password "${REMOTE_DESKTOP_WEB_PASSWORD:-}"
)"
eval "$credential_exports"

password_hash="${REMOTE_DESKTOP_WEB_PASSWORD_MD5:-}"
if [[ -z "$password_hash" ]]; then
  password_hash="$(printf '%s' "$REMOTE_DESKTOP_WEB_PASSWORD" | md5sum | awk '{print $1}')"
fi

mkdir -p "$GUAC_HOME"
chmod 700 "$BUILD_DIR" "$GUAC_HOME"

cat > "$GUAC_HOME/guacamole.properties" <<EOF
guacd-hostname: guacd
guacd-port: 4822
user-mapping: /etc/guacamole/user-mapping.xml
EOF

user_escaped="$(xml_escape "$REMOTE_DESKTOP_WEB_USER")"
host_escaped="$(xml_escape "$REMOTE_DESKTOP_BIND_ADDRESS")"
port_escaped="$(xml_escape "$REMOTE_DESKTOP_PORT")"

cat > "$GUAC_HOME/user-mapping.xml" <<EOF
<user-mapping>
  <authorize username="${user_escaped}" password="${password_hash}" encoding="md5">
    <connection name="Pit Box Desktop">
      <protocol>rdp</protocol>
      <param name="hostname">${host_escaped}</param>
      <param name="port">${port_escaped}</param>
      <param name="security">any</param>
      <param name="ignore-cert">true</param>
    </connection>
  </authorize>
</user-mapping>
EOF
chmod 600 "$GUAC_HOME/user-mapping.xml"

cat > "$BUILD_DIR/docker-compose.yml" <<EOF
services:
  guacd:
    image: ${REMOTE_DESKTOP_GUACD_IMAGE}
    restart: unless-stopped

  guacamole:
    image: ${REMOTE_DESKTOP_GUACAMOLE_IMAGE}
    depends_on:
      - guacd
    restart: unless-stopped
    environment:
      GUACD_HOSTNAME: guacd
      GUACD_PORT: "4822"
      GUACAMOLE_HOME: /etc/guacamole
      WEBAPP_CONTEXT: ROOT
    volumes:
      - ./guacamole-home:/etc/guacamole:ro,Z
    ports:
      - "127.0.0.1:${REMOTE_DESKTOP_WEB_PORT}:8080"
EOF

cat > "$BUILD_DIR/caddy-guacamole.caddy" <<EOF
https://${REMOTE_DESKTOP_WEB_HOSTNAME} {
	tls ${CADDY_CERTS_DIR}/server.crt ${CADDY_CERTS_DIR}/server.key {
		client_auth {
			mode require_and_verify
			trust_pool file ${CADDY_CERTS_DIR}/ca.crt
		}
	}

	encode zstd gzip
	reverse_proxy 127.0.0.1:${REMOTE_DESKTOP_WEB_PORT}

	header {
		X-Content-Type-Options "nosniff"
		X-Frame-Options "SAMEORIGIN"
		Referrer-Policy "no-referrer"
	}
}
EOF

echo "Rendered build/remote-desktop/docker-compose.yml"
echo "Rendered build/remote-desktop/guacamole-home/guacamole.properties"
echo "Rendered build/remote-desktop/guacamole-home/user-mapping.xml"
echo "Rendered build/remote-desktop/caddy-guacamole.caddy"
echo "Safari URL: https://${REMOTE_DESKTOP_WEB_HOSTNAME}/"
echo "Credential source: ${REMOTE_DESKTOP_WEB_PASSWORD_SOURCE:-settings.env}"
