#!/usr/bin/env bash
# Render a loopback-only ttyd LaunchAgent for the temporary macOS Air host.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$ROOT_DIR/configs/webterm/macos-webterm.plist.template"
API_TEMPLATE="$ROOT_DIR/configs/webterm/macos-pit-box-api.plist.template"
OUTPUT_DIR="${1:-$ROOT_DIR/build/macos-webterm}"
TTYD_BINARY="${TTYD_BINARY:-/opt/homebrew/bin/ttyd}"
PYTHON_BINARY="${PIT_BOX_PYTHON_BINARY:-/opt/homebrew/bin/python3}"
WIRING_HARNESS_REPO="${PIT_BOX_WIRING_HARNESS_REPO:-$ROOT_DIR/../wiring-harness}"
WEBTERM_PORT="${WEBTERM_PORT:-7681}"
WEBTERM_API_PORT="${WEBTERM_API_PORT:-7682}"
WEBTERM_TMUX_SESSION="${WEBTERM_TMUX_SESSION:-air}"
WEBTERM_HOST_ID="${WEBTERM_HOST_ID:-air}"
LABEL="dev.user.pit-box.webterm"
API_LABEL="dev.user.pit-box.webterm-api"

[[ -f "$TEMPLATE" ]] || { echo "Missing template: $TEMPLATE" >&2; exit 1; }
[[ -f "$API_TEMPLATE" ]] || { echo "Missing API template: $API_TEMPLATE" >&2; exit 1; }
[[ -x "$TTYD_BINARY" ]] || { echo "ttyd is not executable: $TTYD_BINARY" >&2; exit 1; }
[[ -x "$PYTHON_BINARY" ]] || { echo "Python is not executable: $PYTHON_BINARY" >&2; exit 1; }
[[ -f "$ROOT_DIR/scripts/render_webterm_hosts.py" ]] || { echo "Missing terminal-host renderer" >&2; exit 1; }
[[ -f "$WIRING_HARNESS_REPO/services.toml" ]] || { echo "Missing services registry: $WIRING_HARNESS_REPO/services.toml" >&2; exit 1; }
[[ "$WEBTERM_PORT" =~ ^[0-9]+$ ]] && (( WEBTERM_PORT >= 1024 && WEBTERM_PORT <= 65535 )) || {
  echo "WEBTERM_PORT must be an unprivileged TCP port" >&2
  exit 1
}
[[ "$WEBTERM_API_PORT" =~ ^[0-9]+$ ]] && (( WEBTERM_API_PORT >= 1024 && WEBTERM_API_PORT <= 65535 )) || {
  echo "WEBTERM_API_PORT must be an unprivileged TCP port" >&2
  exit 1
}
[[ "$WEBTERM_API_PORT" != "$WEBTERM_PORT" ]] || {
  echo "WEBTERM_API_PORT must differ from WEBTERM_PORT" >&2
  exit 1
}
[[ "$WEBTERM_TMUX_SESSION" =~ ^[A-Za-z0-9_.-]+$ ]] || {
  echo "WEBTERM_TMUX_SESSION may contain only letters, numbers, dot, underscore, and hyphen" >&2
  exit 1
}

mkdir -p "$OUTPUT_DIR"
chmod 700 "$OUTPUT_DIR"
tmp_file="$OUTPUT_DIR/.${LABEL}.plist.tmp"
output_file="$OUTPUT_DIR/${LABEL}.plist"
api_tmp_file="$OUTPUT_DIR/.${API_LABEL}.plist.tmp"
api_output_file="$OUTPUT_DIR/${API_LABEL}.plist"
index_file="$OUTPUT_DIR/index.html"
home_file="$OUTPUT_DIR/home.html"
hosts_file="$OUTPUT_DIR/terminal-hosts.json"

# Keep the Air page aligned with the installed ttyd version while retaining the
# same mobile toolbar and tmux controls as the Linux Webterm deployment.
# Current ttyd embeds its client bundle in its default page. A custom index
# must therefore be generated dynamically; the tracked fallback targets older
# ttyd releases that fetched a separate client script.
WEBTERM_INDEX_REQUIRE_DYNAMIC=true "$ROOT_DIR/scripts/render_webterm_index.sh" "$index_file"
cp "$ROOT_DIR/configs/webterm/home.html" "$home_file"
chmod 600 "$home_file"
"$PYTHON_BINARY" "$ROOT_DIR/scripts/render_webterm_hosts.py" \
  --services "$WIRING_HARNESS_REPO/services.toml" \
  --current-id "$WEBTERM_HOST_ID" \
  --current-url "http://127.0.0.1:7680/" \
  --output "$hosts_file"

sed \
  -e "s|TTYD_BINARY|$TTYD_BINARY|g" \
  -e "s|WEBTERM_PORT|$WEBTERM_PORT|g" \
  -e "s|WEBTERM_INDEX|$index_file|g" \
  -e "s|TTYD_SESSION_SCRIPT|$ROOT_DIR/scripts/ttyd_session.sh|g" \
  -e "s|WEBTERM_TMUX_SESSION|$WEBTERM_TMUX_SESSION|g" \
  -e "s|WEBTERM_LOG_DIR|$OUTPUT_DIR|g" \
  -e "s|PIT_BOX_ROOT|$ROOT_DIR|g" \
  "$TEMPLATE" > "$tmp_file"
chmod 600 "$tmp_file"
plutil -lint "$tmp_file" >/dev/null
mv -f "$tmp_file" "$output_file"

sed \
  -e "s|PYTHON_BINARY|$PYTHON_BINARY|g" \
  -e "s|PIT_BOX_API_SCRIPT|$ROOT_DIR/scripts/pit_box_api.py|g" \
  -e "s|WEBTERM_API_PORT|$WEBTERM_API_PORT|g" \
  -e "s|WEBTERM_HOSTS_FILE|$hosts_file|g" \
  -e "s|WEBTERM_TMUX_SESSION|$WEBTERM_TMUX_SESSION|g" \
  -e "s|WEBTERM_LOG_DIR|$OUTPUT_DIR|g" \
  -e "s|PIT_BOX_ROOT|$ROOT_DIR|g" \
  "$API_TEMPLATE" > "$api_tmp_file"
chmod 600 "$api_tmp_file"
plutil -lint "$api_tmp_file" >/dev/null
mv -f "$api_tmp_file" "$api_output_file"

echo "Rendered $output_file"
echo "Rendered $api_output_file"
echo "Rendered toolbar page: $index_file"
echo "Rendered home page: $home_file"
echo "LaunchAgent label: $LABEL"
echo "LaunchAgent label: $API_LABEL"
echo "ttyd will bind only to 127.0.0.1:$WEBTERM_PORT; Caddy owns mesh ingress."
echo "pit-box API will bind only to 127.0.0.1:$WEBTERM_API_PORT."
