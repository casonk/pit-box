#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE="$ROOT_DIR/settings.env"
BUILD_DIR="$ROOT_DIR/build/remote-desktop"
INSTALL_DIR="/etc/pit-box/remote-desktop"
CADDY_SOURCE="$BUILD_DIR/caddy-guacamole.caddy"
CADDY_TARGET="/etc/caddy/Caddyfile.d/pit-box-remote-desktop.caddy"
CADDYFILE="/etc/caddy/Caddyfile"

[[ -f "$SETTINGS_FILE" ]] || { echo "Missing settings.env" >&2; exit 1; }
# shellcheck source=/dev/null
source "$SETTINGS_FILE"

: "${REMOTE_DESKTOP_WEB_ENABLED:?Missing REMOTE_DESKTOP_WEB_ENABLED}"
if [[ "$REMOTE_DESKTOP_WEB_ENABLED" != "true" ]]; then
  echo "REMOTE_DESKTOP_WEB_ENABLED is not 'true'. Skipping Safari remote desktop installation."
  exit 0
fi

GUACAMOLE_CONTAINER_UID="${REMOTE_DESKTOP_GUACAMOLE_UID:-1001}"
GUACAMOLE_CONTAINER_GID="${REMOTE_DESKTOP_GUACAMOLE_GID:-1001}"

for src in "$BUILD_DIR/docker-compose.yml" "$BUILD_DIR/guacamole-home/guacamole.properties" "$BUILD_DIR/guacamole-home/user-mapping.xml" "$CADDY_SOURCE"; do
  if [[ ! -f "$src" ]]; then
    echo "Missing rendered file: $src" >&2
    echo "Run ./scripts/render_remote_desktop_gateway.sh first." >&2
    exit 1
  fi
done

install_packages() {
  if command -v podman >/dev/null 2>&1 && command -v podman-compose >/dev/null 2>&1; then
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    apt-get install -y podman podman-compose
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y podman podman-compose
  else
    echo "Unsupported package manager. Install podman and podman-compose manually." >&2
    exit 1
  fi
}

install_packages

mkdir -p "$INSTALL_DIR"
cp "$BUILD_DIR/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml"
rm -rf "$INSTALL_DIR/guacamole-home"
cp -R "$BUILD_DIR/guacamole-home" "$INSTALL_DIR/guacamole-home"
chmod 700 "$INSTALL_DIR"
chown -R "${GUACAMOLE_CONTAINER_UID}:${GUACAMOLE_CONTAINER_GID}" "$INSTALL_DIR/guacamole-home"
chmod 700 "$INSTALL_DIR/guacamole-home"
chmod 600 "$INSTALL_DIR/guacamole-home/guacamole.properties" "$INSTALL_DIR/guacamole-home/user-mapping.xml"

(
  cd "$INSTALL_DIR"
  podman-compose up -d --force-recreate --remove-orphans
)

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
    podman logs --tail=80 remote-desktop_guacamole_1 >&2 || true
    exit 1
  fi
fi

mkdir -p /etc/caddy/Caddyfile.d
cp "$CADDY_SOURCE" "$CADDY_TARGET"
grep -q 'import Caddyfile.d' "$CADDYFILE" || \
  printf '\nimport Caddyfile.d/*.caddy\n' >> "$CADDYFILE"
caddy validate --config "$CADDYFILE"
systemctl reload caddy

echo "Safari remote desktop gateway installed."
echo "  https://${REMOTE_DESKTOP_WEB_HOSTNAME:-<remote-desktop-hostname>}/"
echo "Run scripts/install_remote_desktop.sh too so the xrdp backend is available."
