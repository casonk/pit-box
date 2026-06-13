#!/usr/bin/env bash
# Redeploy rendered web-service configs and restart the affected systemd units.
# Usage: rebuild_webservices.sh [--settings FILE] [ttyd] [api] [dns] [caddy] [cockpit] [rdp] [desktop-web] [user-web] [session-control]
# With no arguments all enabled services are rebuilt.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE="$ROOT_DIR/settings.env"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --settings)
      SETTINGS_FILE="$2"
      [[ "$SETTINGS_FILE" = /* ]] || SETTINGS_FILE="$ROOT_DIR/$SETTINGS_FILE"
      shift 2
      ;;
    *) break;;
  esac
done

[[ -f "$SETTINGS_FILE" ]] || { echo "Missing settings file: $SETTINGS_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$SETTINGS_FILE"
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/site_registry.sh"

WEBTERM_API_PORT="${WEBTERM_API_PORT:-$((WEBTERM_PORT + 1))}"
WEBTERM_ENV_SUFFIX="${WEBTERM_ENV_SUFFIX:-}"
WEBTERM_TMUX_SESSION="${WEBTERM_TMUX_SESSION:-pit-box}"
INSTALL_BASE="/etc/pit-box${WEBTERM_ENV_SUFFIX}"

ALL_SERVICES=()
[[ "${WEBTERM_ENABLED:-false}"  == "true" ]] && ALL_SERVICES+=(ttyd api dns caddy user-web)
[[ "${COCKPIT_ENABLED:-false}"  == "true" ]] && ALL_SERVICES+=(cockpit)
[[ "${REMOTE_DESKTOP_ENABLED:-false}" == "true" ]] && ALL_SERVICES+=(rdp)
[[ "${REMOTE_DESKTOP_WEB_ENABLED:-false}" == "true" ]] && ALL_SERVICES+=(desktop-web)

if [[ ${#ALL_SERVICES[@]} -eq 0 ]]; then
  echo "No web services enabled in ${SETTINGS_FILE}. Nothing to rebuild."
  exit 0
fi

if [[ $# -gt 0 ]]; then
  SERVICES=("$@")
else
  SERVICES=("${ALL_SERVICES[@]}")
fi

ensure_package() {
  local pkg="$1"
  command -v "$pkg" >/dev/null 2>&1 && return 0
  echo "[$pkg] not found — installing..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get install -y "$pkg"
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y "$pkg"
  else
    echo "Unsupported package manager. Install $pkg manually." >&2
    return 1
  fi
}

check_api_post_handler() {
  local remaining=20
  local status
  command -v curl >/dev/null 2>&1 || return 0
  while (( remaining > 0 )); do
    status="$(
      curl -sS -o /dev/null -w '%{http_code}' \
        -X POST "http://127.0.0.1:${WEBTERM_API_PORT}/api/terminals/scroll" || true
    )"
    if [[ "$status" != "501" && "$status" != "000" ]]; then
      return 0
    fi
    remaining=$((remaining - 1))
    sleep 0.25
  done
  echo "pit-box-api did not load the terminal scroll POST handler (HTTP $status)" >&2
  return 1
}

rebuild_ttyd() {
  local svc="$ROOT_DIR/build/webterm/ttyd${WEBTERM_ENV_SUFFIX}.service"
  local api_svc="$ROOT_DIR/build/webterm/pit-box-api${WEBTERM_ENV_SUFFIX}.service"
  [[ -f "$svc" ]] || { echo "Missing $svc — run render_configs.sh first" >&2; return 1; }
  [[ -f "$api_svc" ]] || { echo "Missing $api_svc — run render_configs.sh first" >&2; return 1; }
  ensure_package ttyd
  ensure_package tmux
  mkdir -p "${INSTALL_BASE}/webterm"
  cp "$ROOT_DIR/configs/webterm/home.html" "${INSTALL_BASE}/webterm/home.html"
  install -m 0755 "$ROOT_DIR/scripts/ttyd_session.sh" "${INSTALL_BASE}/ttyd_session.sh"
  install -m 0755 "$ROOT_DIR/scripts/pit_box_api.py" "${INSTALL_BASE}/pit_box_api.py"
  "$ROOT_DIR/scripts/render_webterm_index.sh" "${INSTALL_BASE}/webterm/index.html"

  cp "$svc" "/etc/systemd/system/ttyd${WEBTERM_ENV_SUFFIX}.service"
  cp "$api_svc" "/etc/systemd/system/pit-box-api${WEBTERM_ENV_SUFFIX}.service"
  systemctl daemon-reload
  systemctl enable --now "pit-box-api${WEBTERM_ENV_SUFFIX}"
  systemctl restart "pit-box-api${WEBTERM_ENV_SUFFIX}"
  check_api_post_handler
  systemctl enable --now "ttyd${WEBTERM_ENV_SUFFIX}"
  # Keep ttyd last. This script is often run from inside WebTerm, and restarting
  # ttyd kills the current browser terminal before later commands can run.
  systemctl restart "ttyd${WEBTERM_ENV_SUFFIX}"
  echo "[ok] ttyd${WEBTERM_ENV_SUFFIX} rebuilt (home/API refreshed too)"
}

rebuild_api() {
  local svc="$ROOT_DIR/build/webterm/pit-box-api${WEBTERM_ENV_SUFFIX}.service"
  [[ -f "$svc" ]] || { echo "Missing $svc — run render_configs.sh first" >&2; return 1; }
  install -m 0755 "$ROOT_DIR/scripts/pit_box_api.py" "${INSTALL_BASE}/pit_box_api.py"
  cp "$svc" "/etc/systemd/system/pit-box-api${WEBTERM_ENV_SUFFIX}.service"
  systemctl daemon-reload
  systemctl enable --now "pit-box-api${WEBTERM_ENV_SUFFIX}"
  systemctl restart "pit-box-api${WEBTERM_ENV_SUFFIX}"
  check_api_post_handler
  echo "[ok] pit-box-api${WEBTERM_ENV_SUFFIX} rebuilt"
}

rebuild_caddy() {
  local src="$ROOT_DIR/build/webterm/caddy-webterm${WEBTERM_ENV_SUFFIX}.caddy"
  local caddyfile="/etc/caddy/Caddyfile"
  [[ -f "$src" ]] || { echo "Missing $src — run render_configs.sh first" >&2; return 1; }
  mkdir -p /etc/caddy/Caddyfile.d
  cp "$src" "/etc/caddy/Caddyfile.d/pit-box-webterm${WEBTERM_ENV_SUFFIX}.caddy"
  cleanup_wiring_harness_owned_caddy_dropins
  grep -q 'import Caddyfile.d' "$caddyfile" || \
    printf '\nimport Caddyfile.d/*.caddy\n' >> "$caddyfile"
  caddy validate --config "$caddyfile"
  systemctl reload caddy
  echo "[ok] caddy${WEBTERM_ENV_SUFFIX} rebuilt"
}

cleanup_wiring_harness_owned_caddy_dropins() {
  local desktop_ingress=""
  local desktop_dropin="/etc/caddy/Caddyfile.d/pit-box-remote-desktop.caddy"

  desktop_ingress="$(
    resolve_registry_field "$ROOT_DIR" "pit-box-remote-desktop" ingress 2>/dev/null || true
  )"
  if [[ "$desktop_ingress" == "wiring-harness-caddy" && -f "$desktop_dropin" ]]; then
    rm -f "$desktop_dropin"
    echo "[ok] removed stale $desktop_dropin; wiring-harness owns pit-box-remote-desktop"
  fi
}

rebuild_dns() {
  local src="$ROOT_DIR/build/webterm/dnsmasq-vpn${WEBTERM_ENV_SUFFIX}.conf"
  [[ -f "$src" ]] || { echo "Missing $src — run render_configs.sh first" >&2; return 1; }
  ensure_package dnsmasq
  cp "$src" "/etc/dnsmasq.d/pit-box${WEBTERM_ENV_SUFFIX}-vpn.conf"
  systemctl enable --now dnsmasq
  systemctl restart dnsmasq
  echo "[ok] dnsmasq${WEBTERM_ENV_SUFFIX} rebuilt"
}

rebuild_cockpit() {
  local caddy_src="$ROOT_DIR/build/cockpit/caddy-cockpit${WEBTERM_ENV_SUFFIX}.caddy"
  local caddyfile="/etc/caddy/Caddyfile"
  if [[ -f "$caddy_src" ]]; then
    mkdir -p /etc/caddy/Caddyfile.d
    cp "$caddy_src" "/etc/caddy/Caddyfile.d/pit-box-cockpit${WEBTERM_ENV_SUFFIX}.caddy"
    grep -q 'import Caddyfile.d' "$caddyfile" || \
      printf '\nimport Caddyfile.d/*.caddy\n' >> "$caddyfile"
    caddy validate --config "$caddyfile"
    systemctl reload caddy
  fi
  systemctl enable --now cockpit.socket
  systemctl restart cockpit.socket
  echo "[ok] cockpit${WEBTERM_ENV_SUFFIX} rebuilt"
}

rebuild_rdp() {
  "$ROOT_DIR/scripts/install_remote_desktop.sh"
  echo "[ok] rdp rebuilt"
}

rebuild_desktop_web() {
  "$ROOT_DIR/scripts/render_remote_desktop_gateway.sh" --settings "$SETTINGS_FILE"
  "$ROOT_DIR/scripts/install_remote_desktop_gateway.sh" --settings "$SETTINGS_FILE"
  echo "[ok] desktop-web${WEBTERM_ENV_SUFFIX} rebuilt"
}

_restart_user_service() {
  local svc="$1"
  local uid
  uid="$(id -u "${WEBTERM_USER}")"
  local bus="unix:path=/run/user/${uid}/bus"
  local svc_dir="/home/${WEBTERM_USER}/.config/systemd/user"
  if [[ ! -f "${svc_dir}/${svc}.service" ]]; then
    echo "[skip] ${svc}.service not installed"
    return 0
  fi
  XDG_RUNTIME_DIR="/run/user/${uid}" DBUS_SESSION_BUS_ADDRESS="${bus}" \
    sudo -u "${WEBTERM_USER}" systemctl --user restart "${svc}.service"
  echo "[ok] ${svc}.service restarted"
}

# User-level web services proxied by Caddy. Order is safe — none depend on each other.
_USER_WEB_SERVICES=(
  clockwork-web
  tachometer-dashboard
  intake-web
  magneto-web
  session-control-web
)

rebuild_user_web_services() {
  for svc in "${_USER_WEB_SERVICES[@]}"; do
    _restart_user_service "$svc"
  done
}

rebuild_session_control() {
  _restart_user_service session-control-web
}

rebuild_activate() {
  "$ROOT_DIR/../clockwork/scripts/activate.sh"
  echo "[ok] activate complete"
}

rebuild_smart() {
  "$ROOT_DIR/scripts/render_configs.sh" --settings "$SETTINGS_FILE"

  local need_ttyd=0 need_api=0 need_caddy=0 need_dns=0 need_cockpit=0 need_desktop=0

  if [[ "${WEBTERM_ENABLED:-false}" == "true" ]]; then
    diff -q "$ROOT_DIR/configs/webterm/home.html" \
            "${INSTALL_BASE}/webterm/home.html" >/dev/null 2>&1 || need_ttyd=1
    diff -q "$ROOT_DIR/scripts/ttyd_session.sh" \
            "${INSTALL_BASE}/ttyd_session.sh" >/dev/null 2>&1   || need_ttyd=1
    diff -q "$ROOT_DIR/build/webterm/ttyd${WEBTERM_ENV_SUFFIX}.service" \
            "/etc/systemd/system/ttyd${WEBTERM_ENV_SUFFIX}.service" >/dev/null 2>&1 || need_ttyd=1

    if [[ $need_ttyd -eq 0 ]]; then
      diff -q "$ROOT_DIR/scripts/pit_box_api.py" \
              "${INSTALL_BASE}/pit_box_api.py" >/dev/null 2>&1 || need_api=1
      diff -q "$ROOT_DIR/build/webterm/pit-box-api${WEBTERM_ENV_SUFFIX}.service" \
              "/etc/systemd/system/pit-box-api${WEBTERM_ENV_SUFFIX}.service" >/dev/null 2>&1 || need_api=1
    fi

    local caddy_dst="/etc/caddy/Caddyfile.d/pit-box-webterm${WEBTERM_ENV_SUFFIX}.caddy"
    [[ -f "$caddy_dst" ]] && {
      diff -q "$ROOT_DIR/build/webterm/caddy-webterm${WEBTERM_ENV_SUFFIX}.caddy" \
              "$caddy_dst" >/dev/null 2>&1 || need_caddy=1
    }

    local dns_dst="/etc/dnsmasq.d/pit-box${WEBTERM_ENV_SUFFIX}-vpn.conf"
    [[ -f "$dns_dst" ]] && {
      diff -q "$ROOT_DIR/build/webterm/dnsmasq-vpn${WEBTERM_ENV_SUFFIX}.conf" \
              "$dns_dst" >/dev/null 2>&1 || need_dns=1
    }
  fi

  if [[ "${COCKPIT_ENABLED:-false}" == "true" ]]; then
    local cockpit_src="$ROOT_DIR/build/cockpit/caddy-cockpit${WEBTERM_ENV_SUFFIX}.caddy"
    local cockpit_dst="/etc/caddy/Caddyfile.d/pit-box-cockpit${WEBTERM_ENV_SUFFIX}.caddy"
    [[ -f "$cockpit_src" && -f "$cockpit_dst" ]] && {
      diff -q "$cockpit_src" "$cockpit_dst" >/dev/null 2>&1 || need_cockpit=1
    }
  fi

  if [[ "${REMOTE_DESKTOP_WEB_ENABLED:-false}" == "true" ]]; then
    local rdw_src="$ROOT_DIR/build/remote-desktop${WEBTERM_ENV_SUFFIX}/caddy-guacamole${WEBTERM_ENV_SUFFIX}.caddy"
    local rdw_dst="/etc/caddy/Caddyfile.d/pit-box-remote-desktop${WEBTERM_ENV_SUFFIX}.caddy"
    [[ -f "$rdw_src" && -f "$rdw_dst" ]] && {
      diff -q "$rdw_src" "$rdw_dst" >/dev/null 2>&1 || need_desktop=1
    }
  fi

  local did_rebuild=0
  [[ $need_ttyd    -eq 1 ]] && { rebuild_ttyd;        did_rebuild=1; }
  [[ $need_api     -eq 1 ]] && { rebuild_api;         did_rebuild=1; }
  [[ $need_caddy   -eq 1 ]] && { rebuild_caddy;       did_rebuild=1; }
  [[ $need_dns     -eq 1 ]] && { rebuild_dns;         did_rebuild=1; }
  [[ $need_cockpit -eq 1 ]] && { rebuild_cockpit;     did_rebuild=1; }
  [[ $need_desktop -eq 1 ]] && { rebuild_desktop_web; did_rebuild=1; }

  if [[ $did_rebuild -eq 0 ]]; then
    echo "[ok] all services up to date"
  fi
}

for svc in "${SERVICES[@]}"; do
  case "$svc" in
    smart)   rebuild_smart ;;
    ttyd)    rebuild_ttyd ;;
    api)     rebuild_api ;;
    dns)     rebuild_dns ;;
    caddy)   rebuild_caddy ;;
    cockpit) rebuild_cockpit ;;
    rdp|remote-desktop) rebuild_rdp ;;
    desktop-web|remote-desktop-web|guacamole) rebuild_desktop_web ;;
    activate) rebuild_activate ;;
    user-web) rebuild_user_web_services ;;
    session-control) rebuild_session_control ;;
    *)
      echo "Unknown service: '$svc'  (valid: smart ttyd api dns caddy cockpit rdp desktop-web activate)" >&2
      exit 1
      ;;
  esac
done
