#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE="$ROOT_DIR/settings.env"
SECRETS_DIR="$ROOT_DIR/secrets"
BUILD_DIR="$ROOT_DIR/build"

require_file() {
  local f="$1"
  [[ -f "$f" ]] || { echo "Missing required file: $f" >&2; exit 1; }
}

require_var() {
  local v="$1"
  [[ -n "${!v:-}" ]] || { echo "Missing required variable: $v" >&2; exit 1; }
}

require_file "$SETTINGS_FILE"
require_file "$SECRETS_DIR/server.key"
require_file "$SECRETS_DIR/server.pub"
require_file "$SECRETS_DIR/client.key"
require_file "$SECRETS_DIR/client.pub"

# shellcheck source=/dev/null
source "$SETTINGS_FILE"

for var in SERVER_NAME CLIENT_NAME WG_INTERFACE WG_SERVER_IP WG_SERVER_TUNNEL_IP WG_CLIENT_IP WG_CLIENT_TUNNEL_IP WG_SUBNET_CIDR LAN_IFACE LAN_SUBNET_CIDR LAN_DNS_SERVER WG_LISTEN_PORT PUBLIC_ENDPOINT ROUTING_MODE PERSISTENT_KEEPALIVE; do
  require_var "$var"
done

mkdir -p "$BUILD_DIR/server" "$BUILD_DIR/client" "$BUILD_DIR/ssh"

SERVER_PRIVATE_KEY="$(cat "$SECRETS_DIR/server.key")"
SERVER_PUBLIC_KEY="$(cat "$SECRETS_DIR/server.pub")"
CLIENT_PRIVATE_KEY="$(cat "$SECRETS_DIR/client.key")"
CLIENT_PUBLIC_KEY="$(cat "$SECRETS_DIR/client.pub")"

# When WEBTERM_ENABLED, the client uses the server as its VPN-scoped DNS resolver
# so that WEBTERM_HOSTNAME resolves over the tunnel.
if [[ "${WEBTERM_ENABLED:-false}" == "true" ]]; then
  CLIENT_DNS="$WG_SERVER_TUNNEL_IP"
else
  CLIENT_DNS="$LAN_DNS_SERVER"
fi

case "$ROUTING_MODE" in
  server-only)
    CLIENT_ALLOWED_IPS="$WG_SUBNET_CIDR"
    ;;
  lan)
    CLIENT_ALLOWED_IPS="$WG_SUBNET_CIDR, $LAN_SUBNET_CIDR"
    ;;
  full-tunnel)
    CLIENT_ALLOWED_IPS="0.0.0.0/0, ::/0"
    ;;
  *)
    echo "Invalid ROUTING_MODE: $ROUTING_MODE" >&2
    exit 1
    ;;
esac

cat > "$BUILD_DIR/server/wg0.conf" <<EOF
[Interface]
Address = $WG_SERVER_IP
ListenPort = $WG_LISTEN_PORT
PrivateKey = $SERVER_PRIVATE_KEY

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = ${WG_CLIENT_TUNNEL_IP}/32
EOF

cat > "$BUILD_DIR/client/iphone.conf" <<EOF
[Interface]
Address = $WG_CLIENT_IP
PrivateKey = $CLIENT_PRIVATE_KEY
DNS = $CLIENT_DNS

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $PUBLIC_ENDPOINT
AllowedIPs = $CLIENT_ALLOWED_IPS
PersistentKeepalive = $PERSISTENT_KEEPALIVE
EOF

cat > "$BUILD_DIR/ssh/sshd_config.snippet" <<'EOF'
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
ClientAliveInterval 30
ClientAliveCountMax 6
EOF

echo "Rendered build/server/wg0.conf"
echo "Rendered build/client/iphone.conf"
echo "Rendered build/ssh/sshd_config.snippet"

if [[ "${WEBTERM_ENABLED:-false}" == "true" ]]; then
  : "${WEBTERM_PORT:?WEBTERM_ENABLED=true but WEBTERM_PORT is not set}"
  : "${WEBTERM_HOSTNAME:?WEBTERM_ENABLED=true but WEBTERM_HOSTNAME is not set}"
  : "${WEBTERM_USER:?WEBTERM_ENABLED=true but WEBTERM_USER is not set}"
  : "${CADDY_CERTS_DIR:?WEBTERM_ENABLED=true but CADDY_CERTS_DIR is not set}"
  WEBTERM_API_PORT=$((WEBTERM_PORT + 1))
  mkdir -p "$BUILD_DIR/webterm"
  cat > "$BUILD_DIR/webterm/ttyd.service" <<EOF
[Unit]
Description=ttyd - Web Terminal over WireGuard VPN
Documentation=https://github.com/tsl0922/ttyd
After=network-online.target wg-quick@${WG_INTERFACE}.service
Wants=network-online.target

[Service]
Type=simple
User=${WEBTERM_USER}
# Loopback-only: Caddy proxies from the VPN interface, ttyd is not directly reachable.
# --writable enables keyboard input; tmux provides persistent, multi-window sessions.
# Caddy serves the HTML pages; ttyd only handles the WebSocket and static assets.
ExecStart=/usr/bin/ttyd --writable --interface 127.0.0.1 --port ${WEBTERM_PORT} --ping-interval 30 tmux new-session -A -s pit-box
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  echo "Rendered build/webterm/ttyd.service"

  cat > "$BUILD_DIR/webterm/pit-box-api.service" <<EOF
[Unit]
Description=pit-box web terminal window API
After=network-online.target ttyd.service
Wants=network-online.target

[Service]
Type=simple
User=${WEBTERM_USER}
ExecStart=/usr/bin/python3 /etc/pit-box/pit_box_api.py --port ${WEBTERM_API_PORT} --session pit-box
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  echo "Rendered build/webterm/pit-box-api.service"

  cat > "$BUILD_DIR/webterm/caddy-webterm.caddy" <<EOF
https://${WEBTERM_HOSTNAME} {
	tls ${CADDY_CERTS_DIR}/server.crt ${CADDY_CERTS_DIR}/server.key {
		client_auth {
			mode require_and_verify
			trust_pool file ${CADDY_CERTS_DIR}/ca.crt
		}
	}

	encode zstd gzip

	@home path /
	handle @home {
		root * /etc/pit-box/webterm
		rewrite * /home.html
		file_server
	}

	@term path /term
	handle @term {
		root * /etc/pit-box/webterm
		rewrite * /index.html
		file_server
	}

	@api path_regexp ^/api/
	handle @api {
		reverse_proxy 127.0.0.1:${WEBTERM_API_PORT}
	}

	handle {
		reverse_proxy 127.0.0.1:${WEBTERM_PORT}
	}

	header {
		X-Content-Type-Options "nosniff"
		X-Frame-Options "SAMEORIGIN"
		Referrer-Policy "no-referrer"
	}
}
EOF
  echo "Rendered build/webterm/caddy-webterm.caddy"

  DNS_ADDRESSES="address=/${WEBTERM_HOSTNAME}/${WG_SERVER_TUNNEL_IP}"
  if [[ "${COCKPIT_ENABLED:-false}" == "true" ]]; then
    : "${COCKPIT_HOSTNAME:?COCKPIT_ENABLED=true but COCKPIT_HOSTNAME is not set}"
    DNS_ADDRESSES="${DNS_ADDRESSES}"$'\n'"address=/${COCKPIT_HOSTNAME}/${WG_SERVER_TUNNEL_IP}"
  fi

  cat > "$BUILD_DIR/webterm/dnsmasq-vpn.conf" <<EOF
interface=${WG_INTERFACE}
bind-interfaces
listen-address=${WG_SERVER_TUNNEL_IP}
no-dhcp-interface=${WG_INTERFACE}
server=${LAN_DNS_SERVER}
${DNS_ADDRESSES}
EOF
  echo "Rendered build/webterm/dnsmasq-vpn.conf"
fi
