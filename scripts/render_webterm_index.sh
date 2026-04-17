#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-/etc/pit-box/webterm/index.html}"
PORT="${WEBTERM_INDEX_PORT:-7699}"
FALLBACK_INDEX="$ROOT_DIR/configs/webterm/index.html"

TTYD_BIN="$(command -v ttyd || true)"
[[ -n "$TTYD_BIN" ]] || {
  echo "Missing ttyd. Install it before generating the web terminal index." >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || {
  echo "Missing python3. Install it before generating the web terminal index." >&2
  exit 1
}

mkdir -p "$(dirname "$TARGET")"

tmp_pid=""
cleanup() {
  [[ -n "$tmp_pid" ]] || return 0
  kill "$tmp_pid" 2>/dev/null || true
  wait "$tmp_pid" 2>/dev/null || true
}
trap cleanup EXIT

# Prefer generating the custom page from the locally installed ttyd assets so
# the toolbar keeps working when ttyd's bundled HTML changes across versions.
"$TTYD_BIN" --interface 127.0.0.1 --port "$PORT" sleep 30 &
tmp_pid="$!"

if python3 "$ROOT_DIR/scripts/inject_toolbar.py" --port "$PORT" --target "$TARGET"; then
  echo "[ok] rendered web terminal index at $TARGET"
  exit 0
fi

[[ -f "$FALLBACK_INDEX" ]] || {
  echo "Dynamic ttyd index generation failed and fallback is missing: $FALLBACK_INDEX" >&2
  exit 1
}

cp "$FALLBACK_INDEX" "$TARGET"
echo "[warn] dynamic ttyd index generation failed; copied fallback $FALLBACK_INDEX to $TARGET" >&2
