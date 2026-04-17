#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE="$ROOT_DIR/settings.env"
SERVICE_SOURCE="$ROOT_DIR/build/webterm/ttyd.service"
SERVICE_TARGET="/etc/systemd/system/ttyd.service"
DNS_CONF_SOURCE="$ROOT_DIR/build/webterm/dnsmasq-vpn.conf"
DNS_CONF_TARGET="/etc/dnsmasq.d/pit-box-vpn.conf"
CADDY_CONF_SOURCE="$ROOT_DIR/build/webterm/caddy-webterm.caddy"
CADDY_CONF_TARGET="/etc/caddy/Caddyfile.d/pit-box-webterm.caddy"
CADDYFILE="/etc/caddy/Caddyfile"
HTML_TARGET="/etc/pit-box/webterm/index.html"

[[ -f "$SETTINGS_FILE" ]] || { echo "Missing settings.env" >&2; exit 1; }
# shellcheck source=/dev/null
source "$SETTINGS_FILE"

: "${WEBTERM_ENABLED:?Missing WEBTERM_ENABLED}"
: "${WG_SERVER_TUNNEL_IP:?Missing WG_SERVER_TUNNEL_IP}"
: "${WEBTERM_PORT:?Missing WEBTERM_PORT}"
: "${WEBTERM_HOSTNAME:?Missing WEBTERM_HOSTNAME}"

if [[ "$WEBTERM_ENABLED" != "true" ]]; then
  echo "WEBTERM_ENABLED is not 'true'. Skipping web terminal installation."
  exit 0
fi

for src in "$SERVICE_SOURCE" "$DNS_CONF_SOURCE" "$CADDY_CONF_SOURCE"; do
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
"$ROOT_DIR/scripts/render_webterm_index.sh" "$HTML_TARGET"

cp "$SERVICE_SOURCE" "$SERVICE_TARGET"
systemctl daemon-reload
systemctl enable --now ttyd

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
echo "Helper keys are embedded into the served ttyd page at $HTML_TARGET."
echo "Re-import the client config (dist/pit-box-client.zip) — DNS was updated."
