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
check_file "$ROOT_DIR/scripts/install_remote_desktop.sh"
check_file "$ROOT_DIR/scripts/render_remote_desktop_gateway.sh"
check_file "$ROOT_DIR/scripts/resolve_remote_desktop_password.py"
check_file "$ROOT_DIR/scripts/export_remote_desktop_password_to_keepass.py"
check_file "$ROOT_DIR/scripts/install_remote_desktop_gateway.sh"
check_file "$ROOT_DIR/scripts/rebuild_webservices.sh"
check_file "$ROOT_DIR/scripts/site_registry.sh"
check_file "$ROOT_DIR/scripts/generate_keys.sh"
check_file "$ROOT_DIR/scripts/render_configs.sh"
check_file "$ROOT_DIR/scripts/enable_ip_forwarding.sh"
check_file "$ROOT_DIR/scripts/configure_firewall.sh"
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
check_file "$ROOT_DIR/configs/remote-desktop/xrdp.ini.example"
check_file "$ROOT_DIR/configs/remote-desktop/startwm-pit-box.sh"
check_file "$ROOT_DIR/configs/remote-desktop/docker-compose.guacamole.example.yml"
check_file "$ROOT_DIR/configs/remote-desktop/caddy-guacamole.caddy.example"
check_file "$ROOT_DIR/config/auto-pass.example.ini"
check_file "$ROOT_DIR/docs/remote-desktop.md"

if ! grep -q '^REMOTE_DESKTOP_ENABLED=' "$ROOT_DIR/settings.env.example"; then
  echo "[invalid] settings.env.example missing REMOTE_DESKTOP_ENABLED" >&2
  errors=$((errors + 1))
fi
if ! grep -q '^REMOTE_DESKTOP_WEB_ENABLED=' "$ROOT_DIR/settings.env.example"; then
  echo "[invalid] settings.env.example missing REMOTE_DESKTOP_WEB_ENABLED" >&2
  errors=$((errors + 1))
fi
if ! grep -q '^REMOTE_DESKTOP_GUACAMOLE_UID=' "$ROOT_DIR/settings.env.example"; then
  echo "[invalid] settings.env.example missing REMOTE_DESKTOP_GUACAMOLE_UID" >&2
  errors=$((errors + 1))
fi
if ! grep -q '^REMOTE_DESKTOP_GUACAMOLE_GID=' "$ROOT_DIR/settings.env.example"; then
  echo "[invalid] settings.env.example missing REMOTE_DESKTOP_GUACAMOLE_GID" >&2
  errors=$((errors + 1))
fi
if ! grep -q '^REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_ENTRY=' "$ROOT_DIR/settings.env.example"; then
  echo "[invalid] settings.env.example missing REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_ENTRY" >&2
  errors=$((errors + 1))
fi
if ! grep -q '^REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_PROFILE=' "$ROOT_DIR/settings.env.example"; then
  echo "[invalid] settings.env.example missing REMOTE_DESKTOP_WEB_PASSWORD_KEEPASS_PROFILE" >&2
  errors=$((errors + 1))
fi
if ! grep -q '^REMOTE_DESKTOP_SESSION=' "$ROOT_DIR/settings.env.example"; then
  echo "[invalid] settings.env.example missing REMOTE_DESKTOP_SESSION" >&2
  errors=$((errors + 1))
fi

if [[ -f "$ROOT_DIR/scripts/install_remote_desktop.sh" ]]; then
  if ! grep -q 'xrdp' "$ROOT_DIR/scripts/install_remote_desktop.sh"; then
    echo "[invalid] scripts/install_remote_desktop.sh does not install or manage xrdp" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'wg-quick@${WG_INTERFACE}.service' "$ROOT_DIR/scripts/install_remote_desktop.sh"; then
    echo "[invalid] scripts/install_remote_desktop.sh does not order xrdp after WireGuard" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'detect_desktop_session' "$ROOT_DIR/scripts/install_remote_desktop.sh"; then
    echo "[invalid] scripts/install_remote_desktop.sh does not auto-detect an xrdp desktop session" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'startwm-pit-box.sh' "$ROOT_DIR/scripts/install_remote_desktop.sh"; then
    echo "[invalid] scripts/install_remote_desktop.sh does not install the pit-box xrdp session wrapper" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'ensure_xorg_session' "$ROOT_DIR/scripts/install_remote_desktop.sh"; then
    echo "[invalid] scripts/install_remote_desktop.sh does not enable the xorgxrdp backend" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/scripts/configure_firewall.sh" ]]; then
  if ! grep -q 'configure_firewalld.sh' "$ROOT_DIR/scripts/configure_firewall.sh"; then
    echo "[invalid] scripts/configure_firewall.sh does not route to firewalld" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'configure_ufw.sh' "$ROOT_DIR/scripts/configure_firewall.sh"; then
    echo "[invalid] scripts/configure_firewall.sh does not route to UFW" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/scripts/render_remote_desktop_gateway.sh" ]]; then
  if ! grep -q 'user-mapping.xml' "$ROOT_DIR/scripts/render_remote_desktop_gateway.sh"; then
    echo "[invalid] scripts/render_remote_desktop_gateway.sh does not render Guacamole user mapping" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q './guacamole-home:/etc/guacamole:ro,Z' "$ROOT_DIR/scripts/render_remote_desktop_gateway.sh"; then
    echo "[invalid] scripts/render_remote_desktop_gateway.sh does not apply SELinux label to Guacamole config volume" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'resolve_remote_desktop_password.py' "$ROOT_DIR/scripts/render_remote_desktop_gateway.sh"; then
    echo "[invalid] scripts/render_remote_desktop_gateway.sh does not resolve Guacamole credentials via auto-pass helper" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/scripts/resolve_remote_desktop_password.py" ]]; then
  if ! grep -q 'auto-pass' "$ROOT_DIR/scripts/resolve_remote_desktop_password.py"; then
    echo "[invalid] scripts/resolve_remote_desktop_password.py does not integrate auto-pass" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/scripts/export_remote_desktop_password_to_keepass.py" ]]; then
  if ! grep -q 'upsert_keepassxc_entry' "$ROOT_DIR/scripts/export_remote_desktop_password_to_keepass.py"; then
    echo "[invalid] scripts/export_remote_desktop_password_to_keepass.py does not write through auto-pass" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/scripts/install_remote_desktop_gateway.sh" ]]; then
  if ! grep -q 'chown -R "${GUACAMOLE_CONTAINER_UID}:${GUACAMOLE_CONTAINER_GID}"' "$ROOT_DIR/scripts/install_remote_desktop_gateway.sh"; then
    echo "[invalid] scripts/install_remote_desktop_gateway.sh does not align Guacamole config ownership with the container UID/GID" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'podman logs --tail=80 remote-desktop_guacamole_1' "$ROOT_DIR/scripts/install_remote_desktop_gateway.sh"; then
    echo "[invalid] scripts/install_remote_desktop_gateway.sh does not print Guacamole logs on readiness failure" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'podman-compose up -d --force-recreate --remove-orphans' "$ROOT_DIR/scripts/install_remote_desktop_gateway.sh"; then
    echo "[invalid] scripts/install_remote_desktop_gateway.sh does not recreate containers after compose changes" >&2
    errors=$((errors + 1))
  fi
fi

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
