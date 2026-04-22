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
check_file "$ROOT_DIR/scripts/install_webterm.sh"
check_file "$ROOT_DIR/scripts/rebuild_webservices.sh"
check_file "$ROOT_DIR/scripts/site_registry.sh"
check_file "$ROOT_DIR/scripts/generate_keys.sh"
check_file "$ROOT_DIR/scripts/render_configs.sh"
check_file "$ROOT_DIR/scripts/enable_ip_forwarding.sh"
check_file "$ROOT_DIR/scripts/configure_ufw.sh"
check_file "$ROOT_DIR/scripts/configure_firewalld.sh"
check_file "$ROOT_DIR/scripts/harden_ssh.sh"
check_file "$ROOT_DIR/scripts/package_client.sh"
check_file "$ROOT_DIR/scripts/inject_toolbar.py"
check_file "$ROOT_DIR/scripts/render_webterm_index.sh"
check_file "$ROOT_DIR/scripts/ttyd_session.sh"
check_file "$ROOT_DIR/scripts/pit_box_api.py"
check_file "$ROOT_DIR/configs/webterm/ttyd.service.example"
check_file "$ROOT_DIR/configs/webterm/pit-box-api.service.example"
check_file "$ROOT_DIR/configs/webterm/dnsmasq-vpn.conf.example"
check_file "$ROOT_DIR/configs/webterm/caddy-webterm.caddy.example"
check_file "$ROOT_DIR/configs/webterm/home.html"
check_file "$ROOT_DIR/configs/webterm/index.html"

if [[ -f "$ROOT_DIR/scripts/ttyd_session.sh" ]]; then
  if ! grep -q 'display-message -p -t "\$SESS" "#{window_index}"' "$ROOT_DIR/scripts/ttyd_session.sh"; then
    echo "[invalid] scripts/ttyd_session.sh does not persist the active window on disconnect" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'select-window -t "\$BASE_SESSION:\$current_window"' "$ROOT_DIR/scripts/ttyd_session.sh"; then
    echo "[invalid] scripts/ttyd_session.sh does not restore the base session window on reconnect" >&2
    errors=$((errors + 1))
  fi
fi

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
