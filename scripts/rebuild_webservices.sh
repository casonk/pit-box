#!/usr/bin/env bash
# Redeploy rendered web-service configs and restart the affected systemd units.
# Usage: rebuild_webservices.sh [ttyd] [api] [dns] [caddy] [cockpit]
# With no arguments all enabled services are rebuilt.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE="$ROOT_DIR/settings.env"

[[ -f "$SETTINGS_FILE" ]] || { echo "Missing settings.env" >&2; exit 1; }
# shellcheck source=/dev/null
source "$SETTINGS_FILE"

ALL_SERVICES=()
[[ "${WEBTERM_ENABLED:-false}"  == "true" ]] && ALL_SERVICES+=(ttyd api dns caddy)
[[ "${COCKPIT_ENABLED:-false}"  == "true" ]] && ALL_SERVICES+=(cockpit)

if [[ ${#ALL_SERVICES[@]} -eq 0 ]]; then
  echo "No web services enabled in settings.env. Nothing to rebuild."
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

rebuild_ttyd() {
  local svc="$ROOT_DIR/build/webterm/ttyd.service"
  local api_svc="$ROOT_DIR/build/webterm/pit-box-api.service"
  [[ -f "$svc" ]] || { echo "Missing $svc — run render_configs.sh first" >&2; return 1; }
  [[ -f "$api_svc" ]] || { echo "Missing $api_svc — run render_configs.sh first" >&2; return 1; }
  ensure_package ttyd
  ensure_package tmux
  mkdir -p /etc/pit-box/webterm
  cp "$ROOT_DIR/configs/webterm/home.html" /etc/pit-box/webterm/home.html
  install -m 0755 "$ROOT_DIR/scripts/ttyd_session.sh" /etc/pit-box/ttyd_session.sh
  install -m 0755 "$ROOT_DIR/scripts/pit_box_api.py" /etc/pit-box/pit_box_api.py
  "$ROOT_DIR/scripts/render_webterm_index.sh" /etc/pit-box/webterm/index.html

  cp "$svc" /etc/systemd/system/ttyd.service
  cp "$api_svc" /etc/systemd/system/pit-box-api.service
  systemctl daemon-reload
  systemctl enable --now ttyd
  systemctl enable --now pit-box-api
  systemctl restart ttyd
  systemctl restart pit-box-api
  echo "[ok] ttyd rebuilt (home/API refreshed too)"
}

rebuild_api() {
  local svc="$ROOT_DIR/build/webterm/pit-box-api.service"
  [[ -f "$svc" ]] || { echo "Missing $svc — run render_configs.sh first" >&2; return 1; }
  install -m 0755 "$ROOT_DIR/scripts/pit_box_api.py" /etc/pit-box/pit_box_api.py
  cp "$svc" /etc/systemd/system/pit-box-api.service
  systemctl daemon-reload
  systemctl enable --now pit-box-api
  systemctl restart pit-box-api
  echo "[ok] pit-box-api rebuilt"
}

rebuild_caddy() {
  local src="$ROOT_DIR/build/webterm/caddy-webterm.caddy"
  local caddyfile="/etc/caddy/Caddyfile"
  [[ -f "$src" ]] || { echo "Missing $src — run render_configs.sh first" >&2; return 1; }
  mkdir -p /etc/caddy/Caddyfile.d
  cp "$src" /etc/caddy/Caddyfile.d/pit-box-webterm.caddy
  grep -q 'import Caddyfile.d' "$caddyfile" || \
    printf '\nimport Caddyfile.d/*.caddy\n' >> "$caddyfile"
  caddy validate --config "$caddyfile"
  systemctl reload caddy
  echo "[ok] caddy rebuilt"
}

rebuild_dns() {
  local src="$ROOT_DIR/build/webterm/dnsmasq-vpn.conf"
  [[ -f "$src" ]] || { echo "Missing $src — run render_configs.sh first" >&2; return 1; }
  ensure_package dnsmasq
  cp "$src" /etc/dnsmasq.d/pit-box-vpn.conf
  systemctl enable --now dnsmasq
  systemctl restart dnsmasq
  echo "[ok] dnsmasq rebuilt"
}

rebuild_cockpit() {
  systemctl enable --now cockpit.socket
  systemctl restart cockpit.socket
  echo "[ok] cockpit rebuilt"
}

errors=0
for svc in "${SERVICES[@]}"; do
  case "$svc" in
    ttyd)    rebuild_ttyd    || { echo "[fail] ttyd";    errors=$((errors + 1)); } ;;
    api)     rebuild_api     || { echo "[fail] api";     errors=$((errors + 1)); } ;;
    dns)     rebuild_dns     || { echo "[fail] dns";     errors=$((errors + 1)); } ;;
    caddy)   rebuild_caddy   || { echo "[fail] caddy";   errors=$((errors + 1)); } ;;
    cockpit) rebuild_cockpit || { echo "[fail] cockpit"; errors=$((errors + 1)); } ;;
    *)
      echo "Unknown service: '$svc'  (valid: ttyd api dns caddy cockpit)" >&2
      exit 1
      ;;
  esac
done
[[ $errors -eq 0 ]] || exit 1
