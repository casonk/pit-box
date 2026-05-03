#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE="$ROOT_DIR/settings.env"

if (( EUID != 0 )); then
  echo "This script manages system firewall rules. Run it with sudo:" >&2
  echo "  sudo ./scripts/configure_firewalld.sh" >&2
  exit 1
fi

[[ -f "$SETTINGS_FILE" ]] || { echo "Missing settings.env" >&2; exit 1; }
# shellcheck source=/dev/null
source "$SETTINGS_FILE"

: "${WG_LISTEN_PORT:?Missing WG_LISTEN_PORT}"
: "${WG_INTERFACE:?Missing WG_INTERFACE}"
: "${LAN_IFACE:?Missing LAN_IFACE}"
: "${WG_SUBNET_CIDR:?Missing WG_SUBNET_CIDR}"
: "${LAN_SUBNET_CIDR:?Missing LAN_SUBNET_CIDR}"

systemctl enable --now firewalld

VPN_ZONE="${FIREWALLD_WG_ZONE:-wireguard}"
existing_zone="$(firewall-cmd --permanent --get-zone-of-interface="$WG_INTERFACE" 2>/dev/null || true)"
if [[ -z "$existing_zone" ]]; then
  existing_zone="$(firewall-cmd --get-zone-of-interface="$WG_INTERFACE" 2>/dev/null || true)"
fi

firewall-cmd --permanent --add-port="${WG_LISTEN_PORT}/udp"
if [[ -n "$existing_zone" ]]; then
  VPN_ZONE="$existing_zone"
  echo "Using existing firewalld zone '$VPN_ZONE' for $WG_INTERFACE."
else
  firewall-cmd --permanent --new-zone="$VPN_ZONE" 2>/dev/null || true
  firewall-cmd --permanent --zone="$VPN_ZONE" --add-interface="$WG_INTERFACE"
fi
firewall-cmd --permanent --zone="$VPN_ZONE" --add-service=ssh
firewall-cmd --permanent --zone="$VPN_ZONE" --add-source="$WG_SUBNET_CIDR"

if [[ "${WEBTERM_ENABLED:-false}" == "true" || "${REMOTE_DESKTOP_WEB_ENABLED:-false}" == "true" ]]; then
  firewall-cmd --permanent --zone="$VPN_ZONE" --add-service=https
  firewall-cmd --permanent --zone="$VPN_ZONE" --add-service=dns
fi

if [[ "${COCKPIT_ENABLED:-false}" == "true" ]]; then
  firewall-cmd --permanent --zone="$VPN_ZONE" --add-service=cockpit
fi

if [[ "${REMOTE_DESKTOP_ENABLED:-false}" == "true" ]]; then
  : "${REMOTE_DESKTOP_PORT:?REMOTE_DESKTOP_ENABLED=true but REMOTE_DESKTOP_PORT is not set}"
  firewall-cmd --permanent --zone="$VPN_ZONE" --add-port="${REMOTE_DESKTOP_PORT}/tcp"
fi
firewall-cmd --permanent --add-masquerade

firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i "$WG_INTERFACE" -o "$LAN_IFACE" -s "$WG_SUBNET_CIDR" -d "$LAN_SUBNET_CIDR" -j ACCEPT
firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i "$LAN_IFACE" -o "$WG_INTERFACE" -s "$LAN_SUBNET_CIDR" -d "$WG_SUBNET_CIDR" -j ACCEPT

firewall-cmd --reload
echo "Configured firewalld for WireGuard-only private services."
