#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE="$ROOT_DIR/settings.env"
[[ -f "$SETTINGS_FILE" ]] || { echo "Missing settings.env" >&2; exit 1; }
# shellcheck source=/dev/null
source "$SETTINGS_FILE"

: "${WG_LISTEN_PORT:?Missing WG_LISTEN_PORT}"
: "${WG_INTERFACE:?Missing WG_INTERFACE}"
: "${LAN_IFACE:?Missing LAN_IFACE}"
: "${WG_SUBNET_CIDR:?Missing WG_SUBNET_CIDR}"
: "${LAN_SUBNET_CIDR:?Missing LAN_SUBNET_CIDR}"

ufw allow "${WG_LISTEN_PORT}/udp"
ufw allow in on "$WG_INTERFACE" to any port 22 proto tcp

# Forwarding rules for LAN mode / full-tunnel use cases.
grep -q "DEFAULT_FORWARD_POLICY" /etc/default/ufw && \
  sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw || true

BEFORE_RULES="/etc/ufw/before.rules"
if ! grep -q "wireguard-forward" "$BEFORE_RULES"; then
  cat >> "$BEFORE_RULES" <<EOF

# wireguard-forward
*filter
:ufw-user-forward - [0:0]
-A ufw-user-forward -i $WG_INTERFACE -o $LAN_IFACE -s $WG_SUBNET_CIDR -d $LAN_SUBNET_CIDR -j ACCEPT
-A ufw-user-forward -i $LAN_IFACE -o $WG_INTERFACE -s $LAN_SUBNET_CIDR -d $WG_SUBNET_CIDR -j ACCEPT
COMMIT
EOF
fi

ufw reload
echo "Configured UFW for WireGuard and SSH-over-VPN."
