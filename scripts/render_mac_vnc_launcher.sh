#!/usr/bin/env bash
# Render a double-clickable macOS Screen Sharing launcher (.vncloc) for an
# existing VNC server reachable over WireGuard. Pit-box does not run or manage
# that VNC server; it only generates the launcher. No password is written to
# the file: Screen Sharing prompts once and can save it to the macOS Keychain.
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
    *) echo "Unknown argument: $1" >&2; exit 1;;
  esac
done

[[ -f "$SETTINGS_FILE" ]] || { echo "Missing settings file: $SETTINGS_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$SETTINGS_FILE"

if [[ "${MAC_VNC_ENABLED:-false}" != "true" ]]; then
  echo "MAC_VNC_ENABLED is not 'true'. Skipping macOS VNC launcher."
  exit 0
fi

: "${WG_SERVER_TUNNEL_IP:?Missing WG_SERVER_TUNNEL_IP}"
MAC_VNC_HOST="${MAC_VNC_HOST:-$WG_SERVER_TUNNEL_IP}"
MAC_VNC_PORT="${MAC_VNC_PORT:-5905}"
MAC_VNC_NAME="${MAC_VNC_NAME:-Pit Box VNC}"

[[ "$MAC_VNC_PORT" =~ ^[0-9]+$ ]] || { echo "MAC_VNC_PORT must be numeric: $MAC_VNC_PORT" >&2; exit 1; }
[[ "$MAC_VNC_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "MAC_VNC_HOST has unexpected characters: $MAC_VNC_HOST" >&2; exit 1; }
[[ "$MAC_VNC_NAME" =~ ^[A-Za-z0-9\ _.-]+$ ]] || { echo "MAC_VNC_NAME has unexpected characters: $MAC_VNC_NAME" >&2; exit 1; }

OUT_DIR="$ROOT_DIR/dist/mac"
OUT_FILE="$OUT_DIR/${MAC_VNC_NAME}.vncloc"
mkdir -p "$OUT_DIR"

cat > "$OUT_FILE" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>URL</key>
  <string>vnc://${MAC_VNC_HOST}:${MAC_VNC_PORT}</string>
</dict>
</plist>
PLIST

echo "Rendered $OUT_FILE"
echo "Open it on the Mac while WireGuard is connected; Screen Sharing asks for the VNC password."
