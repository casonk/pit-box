#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE="$ROOT_DIR/settings.env"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --settings)
      SETTINGS_FILE="$2"
      [[ "$SETTINGS_FILE" = /* ]] || SETTINGS_FILE="$ROOT_DIR/$SETTINGS_FILE"
      shift 2
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1;;
  esac
done

CADDYFILE="/etc/caddy/Caddyfile"
QUADLET_DIR="/etc/containers/systemd"

# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/site_registry.sh"

[[ -f "$SETTINGS_FILE" ]] || { echo "Missing settings file: $SETTINGS_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$SETTINGS_FILE"

WEBTERM_ENV_SUFFIX="${WEBTERM_ENV_SUFFIX:-}"
BUILD_DIR="$ROOT_DIR/build/remote-desktop${WEBTERM_ENV_SUFFIX}"
INSTALL_DIR="/etc/pit-box${WEBTERM_ENV_SUFFIX}/remote-desktop"
CADDY_SOURCE="$BUILD_DIR/caddy-guacamole${WEBTERM_ENV_SUFFIX}.caddy"
CADDY_TARGET="/etc/caddy/Caddyfile.d/pit-box-remote-desktop${WEBTERM_ENV_SUFFIX}.caddy"

: "${REMOTE_DESKTOP_WEB_ENABLED:?Missing REMOTE_DESKTOP_WEB_ENABLED}"
if [[ "$REMOTE_DESKTOP_WEB_ENABLED" != "true" ]]; then
  echo "REMOTE_DESKTOP_WEB_ENABLED is not 'true'. Skipping Safari remote desktop installation."
  exit 0
fi

GUACAMOLE_CONTAINER_UID="${REMOTE_DESKTOP_GUACAMOLE_UID:-1001}"
GUACAMOLE_CONTAINER_GID="${REMOTE_DESKTOP_GUACAMOLE_GID:-1001}"
REMOTE_DESKTOP_WEB_INGRESS="$(
  resolve_registry_field "$ROOT_DIR" "pit-box-remote-desktop" ingress 2>/dev/null || true
)"

for src in \
    "$BUILD_DIR/guacamole-home/guacamole.properties" \
    "$BUILD_DIR/guacamole-home/user-mapping.xml" \
    "$BUILD_DIR/pit-box-guacamole${WEBTERM_ENV_SUFFIX}.network" \
    "$BUILD_DIR/pit-box-guacd${WEBTERM_ENV_SUFFIX}.container" \
    "$BUILD_DIR/pit-box-guacamole${WEBTERM_ENV_SUFFIX}.container" \
    "$CADDY_SOURCE"; do
  if [[ ! -f "$src" ]]; then
    echo "Missing rendered file: $src" >&2
    echo "Run ./scripts/render_remote_desktop_gateway.sh first." >&2
    exit 1
  fi
done

install_packages() {
  if command -v podman >/dev/null 2>&1; then
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    apt-get install -y podman
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y podman
  else
    echo "Unsupported package manager. Install podman manually." >&2
    exit 1
  fi
}

install_packages

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/guacamole-home"
cp -R "$BUILD_DIR/guacamole-home" "$INSTALL_DIR/guacamole-home"
chmod 700 "$INSTALL_DIR"
chown -R "${GUACAMOLE_CONTAINER_UID}:${GUACAMOLE_CONTAINER_GID}" "$INSTALL_DIR/guacamole-home"
chmod 700 "$INSTALL_DIR/guacamole-home"
chmod 600 "$INSTALL_DIR/guacamole-home/guacamole.properties" "$INSTALL_DIR/guacamole-home/user-mapping.xml"

# Stop and clean up any containers left from a previous podman-compose install.
for ctr in remote-desktop_guacamole_1 remote-desktop_guacd_1; do
  podman stop "$ctr" &>/dev/null || true
  podman rm "$ctr" &>/dev/null || true
done

# Stop existing quadlet services before replacing their unit files.
for svc in "pit-box-guacamole${WEBTERM_ENV_SUFFIX}.service" "pit-box-guacd${WEBTERM_ENV_SUFFIX}.service"; do
  systemctl is-active "$svc" &>/dev/null && systemctl stop "$svc" || true
done

mkdir -p "$QUADLET_DIR"
install -m 644 "$BUILD_DIR/pit-box-guacamole${WEBTERM_ENV_SUFFIX}.network"   "$QUADLET_DIR/pit-box-guacamole${WEBTERM_ENV_SUFFIX}.network"
install -m 644 "$BUILD_DIR/pit-box-guacd${WEBTERM_ENV_SUFFIX}.container"     "$QUADLET_DIR/pit-box-guacd${WEBTERM_ENV_SUFFIX}.container"
install -m 644 "$BUILD_DIR/pit-box-guacamole${WEBTERM_ENV_SUFFIX}.container" "$QUADLET_DIR/pit-box-guacamole${WEBTERM_ENV_SUFFIX}.container"

systemctl daemon-reload
systemctl start "pit-box-guacamole${WEBTERM_ENV_SUFFIX}.service"

if command -v curl >/dev/null 2>&1; then
  ready=false
  for _ in $(seq 1 30); do
    if curl -fsS --max-time 2 "http://127.0.0.1:${REMOTE_DESKTOP_WEB_PORT}/" >/dev/null 2>&1; then
      ready=true
      break
    fi
    sleep 2
  done
  if [[ "$ready" != "true" ]]; then
    echo "Guacamole did not answer on 127.0.0.1:${REMOTE_DESKTOP_WEB_PORT} within 60 seconds." >&2
    echo "Recent container logs:" >&2
    podman logs --tail=80 "pit-box-guacamole${WEBTERM_ENV_SUFFIX}" >&2 || true
    exit 1
  fi
fi

if [[ "$REMOTE_DESKTOP_WEB_INGRESS" == "wiring-harness-caddy" ]]; then
  echo "Shared wiring-harness Caddy owns ${REMOTE_DESKTOP_WEB_HOSTNAME:-desktop route}; skipping repo Caddy drop-in."
  if [[ -f "$CADDY_TARGET" ]]; then
    rm -f "$CADDY_TARGET"
    echo "Removed stale repo Caddy drop-in: $CADDY_TARGET"
    if [[ -f "$CADDYFILE" ]]; then
      caddy validate --config "$CADDYFILE"
      systemctl reload caddy
    fi
  fi
  echo "Run from ../wiring-harness: sudo python3 scripts/setup_caddy.py --provision"
else
  mkdir -p /etc/caddy/Caddyfile.d
  cp "$CADDY_SOURCE" "$CADDY_TARGET"
  grep -q 'import Caddyfile.d' "$CADDYFILE" || \
    printf '\nimport Caddyfile.d/*.caddy\n' >> "$CADDYFILE"
  caddy validate --config "$CADDYFILE"
  systemctl reload caddy
fi

echo "Safari remote desktop gateway installed."
echo "  https://${REMOTE_DESKTOP_WEB_HOSTNAME:-<remote-desktop-hostname>}/"
echo "Run scripts/install_remote_desktop.sh too so the xrdp backend is available."
