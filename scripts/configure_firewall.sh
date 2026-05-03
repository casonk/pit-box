#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if (( EUID != 0 )); then
  echo "This script manages system firewall rules. Run it with sudo:" >&2
  echo "  sudo ./scripts/configure_firewall.sh" >&2
  exit 1
fi

if command -v firewall-cmd >/dev/null 2>&1; then
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
    echo "Detected active firewalld."
    exec "$SCRIPT_DIR/configure_firewalld.sh"
  fi
fi

if command -v ufw >/dev/null 2>&1; then
  echo "Detected UFW."
  exec "$SCRIPT_DIR/configure_ufw.sh"
fi

if command -v firewall-cmd >/dev/null 2>&1; then
  echo "Detected firewalld."
  exec "$SCRIPT_DIR/configure_firewalld.sh"
fi

echo "Unsupported firewall tooling. Install firewalld or UFW, then rerun this script." >&2
exit 1
