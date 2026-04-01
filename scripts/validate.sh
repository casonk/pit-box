#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

check_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    echo "[ok] $f"
  else
    echo "[missing] $f" >&2
    errors=$((errors + 1))
  fi
}

check_file "$ROOT_DIR/README.md"
check_file "$ROOT_DIR/AGENTS.md"
check_file "$ROOT_DIR/settings.env.example"
check_file "$ROOT_DIR/configs/server/wg0.conf.example"
check_file "$ROOT_DIR/configs/client/iphone.conf.example"
check_file "$ROOT_DIR/configs/ssh/sshd_config.snippet"
check_file "$ROOT_DIR/scripts/install.sh"
check_file "$ROOT_DIR/scripts/install_ubuntu.sh"
check_file "$ROOT_DIR/scripts/install_fedora.sh"
check_file "$ROOT_DIR/scripts/generate_keys.sh"
check_file "$ROOT_DIR/scripts/render_configs.sh"
check_file "$ROOT_DIR/scripts/enable_ip_forwarding.sh"
check_file "$ROOT_DIR/scripts/configure_ufw.sh"
check_file "$ROOT_DIR/scripts/configure_firewalld.sh"
check_file "$ROOT_DIR/scripts/harden_ssh.sh"
check_file "$ROOT_DIR/scripts/package_client.sh"

if [[ -f "$ROOT_DIR/build/server/wg0.conf" ]]; then
  if ! grep -q '^\[Interface\]' "$ROOT_DIR/build/server/wg0.conf"; then
    echo "[invalid] build/server/wg0.conf missing [Interface]" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/build/client/iphone.conf" ]]; then
  if ! grep -q '^Endpoint = ' "$ROOT_DIR/build/client/iphone.conf"; then
    echo "[invalid] build/client/iphone.conf missing Endpoint" >&2
    errors=$((errors + 1))
  fi
fi

if [[ "$errors" -gt 0 ]]; then
  echo "Validation failed with $errors issue(s)." >&2
  exit 1
fi

echo "Validation passed."
