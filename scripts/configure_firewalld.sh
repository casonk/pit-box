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

systemctl enable --now firewalld

firewall-cmd --permanent --add-port="${WG_LISTEN_PORT}/udp"
firewall-cmd --permanent --new-zone=wireguard 2>/dev/null || true
firewall-cmd --permanent --zone=wireguard --add-interface="$WG_INTERFACE"
firewall-cmd --permanent --zone=wireguard --add-service=ssh
firewall-cmd --permanent --zone=wireguard --add-source="$WG_SUBNET_CIDR"

if [[ "${WEBTERM_ENABLED:-false}" == "true" ]]; then
  firewall-cmd --permanent --zone=wireguard --add-service=https
  firewall-cmd --permanent --zone=wireguard --add-service=dns
fi

if [[ "${COCKPIT_ENABLED:-false}" == "true" ]]; then
  firewall-cmd --permanent --zone=wireguard --add-service=cockpit
fi
firewall-cmd --permanent --add-masquerade

firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i "$WG_INTERFACE" -o "$LAN_IFACE" -s "$WG_SUBNET_CIDR" -d "$LAN_SUBNET_CIDR" -j ACCEPT
firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i "$LAN_IFACE" -o "$WG_INTERFACE" -s "$LAN_SUBNET_CIDR" -d "$WG_SUBNET_CIDR" -j ACCEPT

firewall-cmd --reload
echo "Configured firewalld for WireGuard and SSH-over-VPN."
