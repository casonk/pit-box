#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE="$ROOT_DIR/settings.env"
SERVICE_SOURCE="$ROOT_DIR/build/webterm/ttyd.service"
SERVICE_TARGET="/etc/systemd/system/ttyd.service"
API_SERVICE_SOURCE="$ROOT_DIR/build/webterm/pit-box-api.service"
API_SERVICE_TARGET="/etc/systemd/system/pit-box-api.service"
DNS_CONF_SOURCE="$ROOT_DIR/build/webterm/dnsmasq-vpn.conf"
DNS_CONF_TARGET="/etc/dnsmasq.d/pit-box-vpn.conf"
CADDY_CONF_SOURCE="$ROOT_DIR/build/webterm/caddy-webterm.caddy"
CADDY_CONF_TARGET="/etc/caddy/Caddyfile.d/pit-box-webterm.caddy"
CADDYFILE="/etc/caddy/Caddyfile"
HTML_TARGET="/etc/pit-box/webterm/index.html"
HOME_SOURCE="$ROOT_DIR/configs/webterm/home.html"
HOME_TARGET="/etc/pit-box/webterm/home.html"
TTYD_SESSION_TARGET="/etc/pit-box/ttyd_session.sh"
API_SCRIPT_TARGET="/etc/pit-box/pit_box_api.py"

# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/site_registry.sh"

[[ -f "$SETTINGS_FILE" ]] || { echo "Missing settings.env" >&2; exit 1; }
# shellcheck source=/dev/null
source "$SETTINGS_FILE"

: "${WEBTERM_ENABLED:?Missing WEBTERM_ENABLED}"
: "${WG_SERVER_TUNNEL_IP:?Missing WG_SERVER_TUNNEL_IP}"

if [[ "$WEBTERM_ENABLED" != "true" ]]; then
  echo "WEBTERM_ENABLED is not 'true'. Skipping web terminal installation."
  exit 0
fi

populate_site_hostname "$ROOT_DIR" "pit-box-webterm" WEBTERM_HOSTNAME

: "${WEBTERM_PORT:?Missing WEBTERM_PORT}"
: "${WEBTERM_HOSTNAME:?Missing WEBTERM_HOSTNAME}"

for src in "$SERVICE_SOURCE" "$API_SERVICE_SOURCE" "$DNS_CONF_SOURCE" "$CADDY_CONF_SOURCE" "$HOME_SOURCE"; do
  if [[ ! -f "$src" ]]; then
    echo "Missing rendered file: $src" >&2
    echo "Run ./scripts/render_configs.sh first." >&2
    exit 1
  fi
done

if command -v apt-get >/dev/null 2>&1; then
  apt-get install -y ttyd dnsmasq tmux
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y ttyd dnsmasq tmux
else
  echo "Unsupported package manager. Install ttyd, dnsmasq, and tmux manually." >&2
  exit 1
fi

mkdir -p /etc/pit-box/webterm
cp "$HOME_SOURCE" "$HOME_TARGET"
"$ROOT_DIR/scripts/render_webterm_index.sh" "$HTML_TARGET"
install -m 0755 "$ROOT_DIR/scripts/ttyd_session.sh" "$TTYD_SESSION_TARGET"
install -m 0755 "$ROOT_DIR/scripts/pit_box_api.py" "$API_SCRIPT_TARGET"

cp "$SERVICE_SOURCE" "$SERVICE_TARGET"
cp "$API_SERVICE_SOURCE" "$API_SERVICE_TARGET"
systemctl daemon-reload
systemctl enable --now ttyd
systemctl enable --now pit-box-api

cp "$DNS_CONF_SOURCE" "$DNS_CONF_TARGET"
systemctl enable --now dnsmasq
systemctl restart dnsmasq

mkdir -p /etc/caddy/Caddyfile.d
cp "$CADDY_CONF_SOURCE" "$CADDY_CONF_TARGET"
grep -q 'import Caddyfile.d' "$CADDYFILE" || \
  printf '\nimport Caddyfile.d/*.caddy\n' >> "$CADDYFILE"
caddy validate --config "$CADDYFILE"
systemctl reload caddy

echo "Web terminal installed and started."
echo "  https://${WEBTERM_HOSTNAME}/"
echo "Only reachable over the WireGuard VPN — not exposed to the public internet."
echo "Home page and helper controls are served from $HOME_TARGET and $HTML_TARGET."
echo "Re-import the client config (dist/pit-box-client.zip) — DNS was updated."
