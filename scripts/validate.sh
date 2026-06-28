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
  if ! grep -q 'podman logs --tail=80 "$GUACAMOLE_CONTAINER"' "$ROOT_DIR/scripts/install_remote_desktop_gateway.sh"; then
    echo "[invalid] scripts/install_remote_desktop_gateway.sh does not print Guacamole logs on readiness failure" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'GUACAMOLE_SERVICE="pit-box-guacamole${WEBTERM_ENV_SUFFIX}.service"' "$ROOT_DIR/scripts/install_remote_desktop_gateway.sh" || ! grep -q 'systemctl start "$GUACAMOLE_SERVICE"' "$ROOT_DIR/scripts/install_remote_desktop_gateway.sh"; then
    echo "[invalid] scripts/install_remote_desktop_gateway.sh does not start the Quadlet Guacamole service" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'rm -f "$CADDY_TARGET"' "$ROOT_DIR/scripts/install_remote_desktop_gateway.sh"; then
    echo "[invalid] scripts/install_remote_desktop_gateway.sh does not remove stale repo Caddy drop-ins for wiring-harness-owned desktop sites" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/scripts/rebuild_webservices.sh" ]]; then
  if ! grep -q 'cleanup_wiring_harness_owned_caddy_dropins' "$ROOT_DIR/scripts/rebuild_webservices.sh"; then
    echo "[invalid] scripts/rebuild_webservices.sh does not clean stale wiring-harness-owned Caddy drop-ins" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'check_api_post_handler' "$ROOT_DIR/scripts/rebuild_webservices.sh"; then
    echo "[invalid] scripts/rebuild_webservices.sh does not verify the running pit-box-api POST handler after restart" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'WEBTERM_API_PORT="${WEBTERM_API_PORT:-\$((WEBTERM_PORT + 1))}"' "$ROOT_DIR/scripts/rebuild_webservices.sh"; then
    echo "[invalid] scripts/rebuild_webservices.sh does not derive WEBTERM_API_PORT for targeted API rebuilds" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'Keep ttyd last' "$ROOT_DIR/scripts/rebuild_webservices.sh"; then
    echo "[invalid] scripts/rebuild_webservices.sh can restart ttyd before coupled API work finishes" >&2
    errors=$((errors + 1))
  fi
  if grep -q 'rebuild_caddy.*||' "$ROOT_DIR/scripts/rebuild_webservices.sh"; then
    echo "[invalid] scripts/rebuild_webservices.sh can mask rebuild_caddy failures inside a Bash errexit-disabled context" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/scripts/ttyd_session.sh" ]]; then
  if ! grep -q 'set-option -t "\$BASE_SESSION" mouse on' "$ROOT_DIR/scripts/ttyd_session.sh"; then
    echo "[invalid] scripts/ttyd_session.sh does not enable tmux mouse handling for the base WebTerm session" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'set-option -t "\$SESS" mouse on' "$ROOT_DIR/scripts/ttyd_session.sh"; then
    echo "[invalid] scripts/ttyd_session.sh does not enable tmux mouse handling for per-browser WebTerm sessions" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'display-message -p -t "\$SESS" "#{window_index}"' "$ROOT_DIR/scripts/ttyd_session.sh"; then
    echo "[invalid] scripts/ttyd_session.sh does not persist the active window on disconnect" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'select-window -t "\$BASE_SESSION:\$current_window"' "$ROOT_DIR/scripts/ttyd_session.sh"; then
    echo "[invalid] scripts/ttyd_session.sh does not restore the base session window on reconnect" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/scripts/pit_box_api.py" ]]; then
  if ! grep -q '/api/terminals/scroll' "$ROOT_DIR/scripts/pit_box_api.py"; then
    echo "[invalid] scripts/pit_box_api.py does not expose the WebTerm terminal scroll API" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'tmux("copy-mode", "-t", target)' "$ROOT_DIR/scripts/pit_box_api.py"; then
    echo "[invalid] scripts/pit_box_api.py does not enter tmux copy-mode directly for touch scrolling" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'pane_current_command' "$ROOT_DIR/scripts/pit_box_api.py" || ! grep -q '"C-Up"' "$ROOT_DIR/scripts/pit_box_api.py"; then
    echo "[invalid] scripts/pit_box_api.py does not route Codex-like foreground app scrolling through Ctrl-Up/Ctrl-Down" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q '/api/snowbridge/repair' "$ROOT_DIR/scripts/pit_box_api.py" || ! grep -q 'setup_share_bind_mount_watch.sh --install-systemd' "$ROOT_DIR/scripts/pit_box_api.py"; then
    echo "[invalid] scripts/pit_box_api.py does not expose the Snowbridge share repair action" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q '/api/airplay/control' "$ROOT_DIR/scripts/pit_box_api.py" || ! grep -q 'AIRPLAY_ADB_TARGET' "$ROOT_DIR/settings.env.example"; then
    echo "[invalid] AirPlay control API/configuration is incomplete" >&2
    errors=$((errors + 1))
  fi
  airplay_example_target="$(sed -n 's/^AIRPLAY_ADB_TARGET=//p' "$ROOT_DIR/settings.env.example")"
  if [[ ! "$airplay_example_target" =~ ^192\.0\.2\.[0-9]+:5555$ ]]; then
    echo "[invalid] example AIRPLAY_ADB_TARGET must use IANA TEST-NET-1, never a local/private address" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'send-keys", "-t", target, "-X"' "$ROOT_DIR/scripts/pit_box_api.py"; then
    echo "[invalid] scripts/pit_box_api.py does not drive tmux copy-mode scrolling through send-keys -X" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/scripts/render_configs.sh" ]]; then
  if ! grep -q '@term_ttyd path /term/token /term/ws' "$ROOT_DIR/scripts/render_configs.sh"; then
    echo "[invalid] scripts/render_configs.sh does not route ttyd subpath token/WebSocket endpoints" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'uri strip_prefix /term' "$ROOT_DIR/scripts/render_configs.sh"; then
    echo "[invalid] scripts/render_configs.sh does not strip /term before proxying ttyd endpoints" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/scripts/inject_toolbar.py" ]]; then
  if ! grep -q 'MutationObserver' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not wait for ttyd to create the terminal container" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'termRef.options.fontSize' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not apply zoom through xterm fontSize" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'FONT_DEFAULT = 17' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not set the WebTerm default font size to 17pt" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'dispatchResize' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not notify ttyd after terminal font-size changes" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'termRef.scrollPages' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not use xterm scrollPages for page navigation" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'termRef.scrollToBottom' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not use xterm scrollToBottom for page navigation" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'setViewportScrollTop' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not include a viewport fallback for page navigation" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'scrollToTerminalLine' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not scroll WebTerm by explicit xterm line targets" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'KEY_PAGE_UP' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not define a tmux PageUp key for WebTerm navigation" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'KEY_PAGE_DOWN' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not define a tmux PageDown key for WebTerm navigation" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'KEY_CTRL_UP' "$ROOT_DIR/scripts/inject_toolbar.py" || ! grep -q 'KEY_CTRL_DOWN' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not keep tmux Ctrl-Up/Ctrl-Down copy-mode fallback keys" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'scrollTerminalsViaApi' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not route terminal finger scrolling through the loopback API" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'isXtermMouseEventsActive' "$ROOT_DIR/scripts/inject_toolbar.py" || ! grep -q '.xterm.enable-mouse-events' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not leave native xterm/tmux mouse scrolling active for apps like Codex" >&2
    errors=$((errors + 1))
  fi
  if grep -q 'sendTmuxCopyCommand(command, rowCount)' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py still sends foreground terminal keys for finger scrolling" >&2
    errors=$((errors + 1))
  fi
  if ! grep -Fq "sendTmux(KEY_PAGE_UP)" "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not use tmux prefix+PageUp for WebTerm page-up" >&2
    errors=$((errors + 1))
  fi
  if grep -Fq "sendTmux('[')" "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py uses tmux prefix+[ for touch scrolling, which can leak '[' at a shell prompt" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'installTerminalTouchScroll' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not install mobile terminal touch scrolling" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'pointermove' "$ROOT_DIR/scripts/inject_toolbar.py" || ! grep -q 'beginTerminalTouchScroll' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not handle pointer-based terminal finger scrolling" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'isPointInStage' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not fall back to coordinate-based terminal touch targeting" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'installKeyboardInsetHandler' "$ROOT_DIR/scripts/inject_toolbar.py" || ! grep -q 'visualViewport' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not react to the mobile visual keyboard viewport" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q -- '--pb-keyboard-offset' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not shift the WebTerm layout above the mobile keyboard" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'pointerup' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not handle touch/pointer toolbar activation" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'data-page="bottom"' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not place Bottom in the page navigation row" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'data-kill="-window"' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not include the guarded current-window kill button" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q '#pb-toolbar .pb-row' "$ROOT_DIR/scripts/inject_toolbar.py" || ! grep -q 'flex-direction: row;' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not keep landscape toolbar button groups horizontal" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'pb-confirm' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not visibly confirm the kill button before executing" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'killCurrentTmuxWindow' "$ROOT_DIR/scripts/inject_toolbar.py" || ! grep -Fq "sendTmux('&')" "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not kill the tmux window visible in the current browser client" >&2
    errors=$((errors + 1))
  fi
  if grep -q "sendTmux('d')" "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py still detaches the browser client instead of killing the visible tmux window" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'pb-clip-panel' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not include a native clipboard panel for selection and paste fallback" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'inset: 0' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py clipboard panel is not full-screen" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'collectBufferText' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not expose terminal scrollback to the select clipboard panel" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'collectDomText' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not fall back to visible terminal DOM text for selection" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'data-clip-send' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not include a manual paste/send fallback control" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'pb-clip-title' "$ROOT_DIR/scripts/inject_toolbar.py" || ! grep -q "panel.setAttribute('data-mode'" "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not visibly distinguish select and paste clipboard panels" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'fallbackCopyText' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not fall back when browser clipboard writes fail" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'function isPasteControl' "$ROOT_DIR/scripts/inject_toolbar.py" || ! grep -Fq 'if (!button || isPasteControl(button))' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not reserve normal click activation for clipboard reads" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'shouldPreserveTerminalFocus' "$ROOT_DIR/scripts/inject_toolbar.py" || ! grep -q 'scheduleTerminalFocus' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not preserve the mobile keyboard across ordinary toolbar actions" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'Math.max(16, readFontSize())' "$ROOT_DIR/scripts/inject_toolbar.py" || ! grep -q 'maximum-scale=1.0, user-scalable=no' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not guard the clipboard panel against mobile focus zoom" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'installClipTouchScroll' "$ROOT_DIR/scripts/inject_toolbar.py" || ! grep -q 'data-clip-scroll-installed' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not install explicit clip-panel touch scrolling" >&2
    errors=$((errors + 1))
  fi
  if grep -q 'area.select()' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py still auto-selects the full clipboard textarea and can trigger mobile zoom" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q -- '--pb-toolbar-h: 204px' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not reserve height for the three-row toolbar" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q '@media (orientation: landscape)' "$ROOT_DIR/scripts/inject_toolbar.py" || ! grep -q -- '--pb-toolbar-h: 52px' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py does not compact the WebTerm toolbar in landscape" >&2
    errors=$((errors + 1))
  fi
  if grep -q 'data-scroll' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py still uses direct viewport scroll controls" >&2
    errors=$((errors + 1))
  fi
  if grep -q -- '--pb-scale' "$ROOT_DIR/scripts/inject_toolbar.py"; then
    echo "[invalid] scripts/inject_toolbar.py still uses container transform scaling" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/configs/webterm/caddy-webterm.caddy.example" ]]; then
  if ! grep -q '@term_ttyd path /term/token /term/ws' "$ROOT_DIR/configs/webterm/caddy-webterm.caddy.example"; then
    echo "[invalid] configs/webterm/caddy-webterm.caddy.example does not document ttyd subpath endpoint routing" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'uri strip_prefix /term' "$ROOT_DIR/configs/webterm/caddy-webterm.caddy.example"; then
    echo "[invalid] configs/webterm/caddy-webterm.caddy.example does not strip /term before proxying ttyd endpoints" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/configs/webterm/home.html" ]]; then
  if ! grep -q 'data-snowbridge-repair' "$ROOT_DIR/configs/webterm/home.html" || ! grep -q '/api/snowbridge/repair' "$ROOT_DIR/configs/webterm/home.html"; then
    echo "[invalid] configs/webterm/home.html does not expose the Snowbridge repair button" >&2
    errors=$((errors + 1))
  fi
fi

if [[ -f "$ROOT_DIR/configs/webterm/index.html" ]]; then
  if ! grep -q 'MutationObserver' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not wait for ttyd to create the terminal container" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'termRef.options.fontSize' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not apply zoom through xterm fontSize" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'FONT_DEFAULT = 17' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not set the WebTerm default font size to 17pt" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'dispatchResize' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not notify ttyd after terminal font-size changes" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'termRef.scrollPages' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not use xterm scrollPages for page navigation" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'termRef.scrollToBottom' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not use xterm scrollToBottom for page navigation" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'setViewportScrollTop' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not include a viewport fallback for page navigation" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'scrollToTerminalLine' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not scroll WebTerm by explicit xterm line targets" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'KEY_PAGE_UP' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not define a tmux PageUp key for WebTerm navigation" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'KEY_PAGE_DOWN' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not define a tmux PageDown key for WebTerm navigation" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'KEY_CTRL_UP' "$ROOT_DIR/configs/webterm/index.html" || ! grep -q 'KEY_CTRL_DOWN' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not keep tmux Ctrl-Up/Ctrl-Down copy-mode fallback keys" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'scrollTerminalsViaApi' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not route terminal finger scrolling through the loopback API" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'isXtermMouseEventsActive' "$ROOT_DIR/configs/webterm/index.html" || ! grep -q '.xterm.enable-mouse-events' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not leave native xterm/tmux mouse scrolling active for apps like Codex" >&2
    errors=$((errors + 1))
  fi
  if grep -q 'sendTmuxCopyCommand(command, rowCount)' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback still sends foreground terminal keys for finger scrolling" >&2
    errors=$((errors + 1))
  fi
  if ! grep -Fq "sendTmux(KEY_PAGE_UP)" "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not use tmux prefix+PageUp for WebTerm page-up" >&2
    errors=$((errors + 1))
  fi
  if grep -Fq "sendTmux('[')" "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback uses tmux prefix+[ for touch scrolling, which can leak '[' at a shell prompt" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'installTerminalTouchScroll' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not install mobile terminal touch scrolling" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'pointermove' "$ROOT_DIR/configs/webterm/index.html" || ! grep -q 'beginTerminalTouchScroll' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not handle pointer-based terminal finger scrolling" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'isPointInStage' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not fall back to coordinate-based terminal touch targeting" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'installKeyboardInsetHandler' "$ROOT_DIR/configs/webterm/index.html" || ! grep -q 'visualViewport' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not react to the mobile visual keyboard viewport" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q -- '--pb-keyboard-offset' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not shift the WebTerm layout above the mobile keyboard" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'pointerup' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not handle touch/pointer toolbar activation" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'data-page="bottom"' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not place Bottom in the page navigation row" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'data-kill="-window"' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not include the guarded current-window kill button" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q '#pb-toolbar .pb-row' "$ROOT_DIR/configs/webterm/index.html" || ! grep -q 'flex-direction: row;' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not keep landscape toolbar button groups horizontal" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'pb-confirm' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not visibly confirm the kill button before executing" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'killCurrentTmuxWindow' "$ROOT_DIR/configs/webterm/index.html" || ! grep -Fq "sendTmux('&')" "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not kill the tmux window visible in the current browser client" >&2
    errors=$((errors + 1))
  fi
  if grep -q "sendTmux('d')" "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback still detaches the browser client instead of killing the visible tmux window" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'pb-clip-panel' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not include a native clipboard panel for selection and paste fallback" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'inset: 0' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback clipboard panel is not full-screen" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'collectBufferText' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not expose terminal scrollback to the select clipboard panel" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'collectDomText' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not fall back to visible terminal DOM text for selection" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'data-clip-send' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not include a manual paste/send fallback control" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'pb-clip-title' "$ROOT_DIR/configs/webterm/index.html" || ! grep -q "panel.setAttribute('data-mode'" "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not visibly distinguish select and paste clipboard panels" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'fallbackCopyText' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not fall back when browser clipboard writes fail" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'function isPasteControl' "$ROOT_DIR/configs/webterm/index.html" || ! grep -Fq 'if (!button || isPasteControl(button))' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not reserve normal click activation for clipboard reads" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'shouldPreserveTerminalFocus' "$ROOT_DIR/configs/webterm/index.html" || ! grep -q 'scheduleTerminalFocus' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not preserve the mobile keyboard across ordinary toolbar actions" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'Math.max(16, readFontSize())' "$ROOT_DIR/configs/webterm/index.html" || ! grep -q 'maximum-scale=1.0, user-scalable=no' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not guard the clipboard panel against mobile focus zoom" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q 'installClipTouchScroll' "$ROOT_DIR/configs/webterm/index.html" || ! grep -q 'data-clip-scroll-installed' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not install explicit clip-panel touch scrolling" >&2
    errors=$((errors + 1))
  fi
  if grep -q 'area.select()' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback still auto-selects the full clipboard textarea and can trigger mobile zoom" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q -- '--pb-toolbar-h: 204px' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not reserve height for the three-row toolbar" >&2
    errors=$((errors + 1))
  fi
  if ! grep -q '@media (orientation: landscape)' "$ROOT_DIR/configs/webterm/index.html" || ! grep -q -- '--pb-toolbar-h: 52px' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback does not compact the WebTerm toolbar in landscape" >&2
    errors=$((errors + 1))
  fi
  if grep -q 'data-scroll' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback still uses direct viewport scroll controls" >&2
    errors=$((errors + 1))
  fi
  if grep -q -- '--pb-scale' "$ROOT_DIR/configs/webterm/index.html"; then
    echo "[invalid] configs/webterm/index.html fallback still uses container transform scaling" >&2
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
