#!/usr/bin/env bash
# Activate the temporary Air Webterm only through its reviewed WireGuard mTLS edge.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WIRING_HARNESS_REPO="${PIT_BOX_WIRING_HARNESS_REPO:-$ROOT_DIR/../wiring-harness}"
SHORT_CIRCUIT_REPO="${PIT_BOX_SHORT_CIRCUIT_REPO:-$ROOT_DIR/../short-circuit}"
WEBTERM_LABEL="dev.user.pit-box.webterm"
WEBTERM_API_LABEL="dev.user.pit-box.webterm-api"
CADDY_LABEL="dev.user.wiring-harness.macos-private-edge"
WEBTERM_PLIST="$ROOT_DIR/build/macos-webterm/${WEBTERM_LABEL}.plist"
WEBTERM_API_PLIST="$ROOT_DIR/build/macos-webterm/${WEBTERM_API_LABEL}.plist"
CADDY_RENDER_DIR="$WIRING_HARNESS_REPO/config/macos-private-edge.local"
CADDY_PLIST="$CADDY_RENDER_DIR/${CADDY_LABEL}.plist"
WIREGUARD_PROFILE="${PIT_BOX_AIR_WIREGUARD_PROFILE:-$SHORT_CIRCUIT_REPO/config/wireguard/mesh.local.d/rendered/generation-2/air/air.conf}"
WIREGUARD_INTERFACE="${PIT_BOX_AIR_WIREGUARD_INTERFACE:-utun7}"
PYTHON_BINARY="${PIT_BOX_PYTHON_BINARY:-/opt/homebrew/bin/python3}"
GUI_DOMAIN="gui/$(id -u)"
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: activate_macos_air_webterm.sh [--dry-run]

Brings up the reviewed Air WireGuard profile when its utun7 interface is absent,
starts loopback-only ttyd and its terminal-state API, renders the exact-IP mTLS Caddy edge, and verifies
local readiness. It never creates a LAN/WAN or wildcard listener.
EOF
}

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
elif [[ $# -ne 0 ]]; then
  usage >&2
  exit 2
fi

run() {
  printf '+' >&2
  printf ' %q' "$@" >&2
  printf '\n' >&2
  "$DRY_RUN" || "$@"
}

restart_launch_agent() {
  local label="$1"
  local plist="$2"
  local installed_plist="$HOME/Library/LaunchAgents/${label}.plist"

  if ! "$DRY_RUN" && /bin/launchctl print "$GUI_DOMAIN/$label" >/dev/null 2>&1; then
    run /bin/launchctl bootout "$GUI_DOMAIN/$label"
  fi
  run /usr/bin/install -m 600 "$plist" "$installed_plist"
  run /bin/launchctl bootstrap "$GUI_DOMAIN" "$installed_plist"
}

[[ "$(uname -s)" == "Darwin" ]] || { echo "This activation script is macOS-only." >&2; exit 1; }
for executable in /opt/homebrew/bin/ttyd /opt/homebrew/bin/tmux /opt/homebrew/bin/wg-quick /opt/homebrew/bin/caddy "$PYTHON_BINARY" /usr/bin/plutil /bin/launchctl /sbin/ifconfig; do
  [[ -x "$executable" ]] || { echo "Missing required executable: $executable" >&2; exit 1; }
done
"$PYTHON_BINARY" -c 'import tomllib' || {
  echo "Python must provide tomllib (Python 3.11+): $PYTHON_BINARY" >&2
  exit 1
}
for required_path in "$ROOT_DIR/scripts/render_macos_webterm_launch_agent.sh" "$WIRING_HARNESS_REPO/scripts/render_macos_private_edge.py" "$WIRING_HARNESS_REPO/scripts/check_macos_air_live.py" "$WIREGUARD_PROFILE"; do
  [[ -f "$required_path" ]] || { echo "Missing required file: $required_path" >&2; exit 1; }
done

if /sbin/ifconfig "$WIREGUARD_INTERFACE" >/dev/null 2>&1; then
  echo "WireGuard interface $WIREGUARD_INTERFACE is already present; preserving its current configuration."
else
  run /usr/bin/sudo /opt/homebrew/bin/wg-quick up "$WIREGUARD_PROFILE"
fi

run "$ROOT_DIR/scripts/render_macos_webterm_launch_agent.sh"
restart_launch_agent "$WEBTERM_LABEL" "$WEBTERM_PLIST"
restart_launch_agent "$WEBTERM_API_LABEL" "$WEBTERM_API_PLIST"

# The renderer validates the exact configured utun /32 before producing the
# Caddyfile. It therefore cannot accidentally expose ttyd on Wi-Fi, LAN, or WAN.
run "$PYTHON_BINARY" "$WIRING_HARNESS_REPO/scripts/render_macos_private_edge.py" --validate-caddy
restart_launch_agent "$CADDY_LABEL" "$CADDY_PLIST"
run "$PYTHON_BINARY" "$WIRING_HARNESS_REPO/scripts/check_macos_air_live.py" readiness

if "$DRY_RUN"; then
  echo "Dry run complete; no Air services or network state were changed."
else
  echo "Air Webterm is active through the reviewed mTLS WireGuard edge."
fi
