#!/usr/bin/env bash
# Per-connection tmux grouped session so each browser tab can independently
# select which window is active without affecting other open tabs. On
# disconnect, sync the tab's last active window back to the base session so the
# next reconnect does not snap back to window 0.
set -euo pipefail

BASE_SESSION="${1:-pit-box}"

# Ensure the base session exists (no-op if already running).
tmux new-session -d -s "$BASE_SESSION" 2>/dev/null || true
# Let xterm touch gestures become tmux wheel events. tmux forwards them to
# mouse-aware apps and uses copy-mode for normal shell scrollback.
tmux set-option -t "$BASE_SESSION" mouse on

# Create a unique grouped session sharing the window set of the base session.
SESS="pb-$$"
tmux new-session -d -t "$BASE_SESSION" -s "$SESS"
tmux set-option -t "$SESS" mouse on

# Attach. When the WebSocket disconnects, remember the last active window so a
# fresh grouped session inherits it on the next connect.
tmux attach-session -t "$SESS"
current_window="$(tmux display-message -p -t "$SESS" "#{window_index}" 2>/dev/null || true)"
if [[ "$current_window" =~ ^[0-9]+$ ]]; then
  tmux select-window -t "$BASE_SESSION:$current_window" 2>/dev/null || true
fi
tmux kill-session -t "$SESS" 2>/dev/null || true
