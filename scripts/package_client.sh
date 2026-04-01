#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT_CONF="$ROOT_DIR/build/client/iphone.conf"
DIST_DIR="$ROOT_DIR/dist"

[[ -f "$CLIENT_CONF" ]] || { echo "Missing $CLIENT_CONF. Run ./scripts/render_configs.sh first." >&2; exit 1; }

mkdir -p "$DIST_DIR"
cp "$CLIENT_CONF" "$DIST_DIR/iphone.conf"

if command -v qrencode >/dev/null 2>&1; then
  qrencode -t ANSIUTF8 < "$CLIENT_CONF" > "$DIST_DIR/iphone-qr.txt"
else
  printf '%s\n' "qrencode not installed; QR text not generated." > "$DIST_DIR/iphone-qr.txt"
fi

(
  cd "$DIST_DIR"
  zip -r "pit-box-client.zip" "iphone.conf" "iphone-qr.txt" >/dev/null
)

echo "Packaged client bundle at dist/pit-box-client.zip"
