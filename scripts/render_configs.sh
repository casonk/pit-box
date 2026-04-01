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
DNS = $LAN_DNS_SERVER

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
EOF

echo "Rendered build/server/wg0.conf"
echo "Rendered build/client/iphone.conf"
echo "Rendered build/ssh/sshd_config.snippet"
