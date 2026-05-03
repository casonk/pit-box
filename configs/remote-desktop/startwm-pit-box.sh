#!/usr/bin/env bash
# Start a deterministic X11 desktop for xrdp sessions.

set -euo pipefail

desktop_id="${PIT_BOX_XRDP_DESKTOP_SESSION:-}"
env_file="${PIT_BOX_XRDP_ENV_FILE:-/etc/xrdp/startwm-pit-box.env}"

if [[ -f "$env_file" ]]; then
  # shellcheck source=/dev/null
  source "$env_file"
  desktop_id="${PIT_BOX_XRDP_DESKTOP_SESSION:-$desktop_id}"
fi

session_file_for() {
  local name="$1"
  local candidate
  for candidate in \
    "/usr/share/xsessions/${name}.desktop" \
    "/usr/local/share/xsessions/${name}.desktop"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

select_session_file() {
  local session_dir candidate name

  if [[ -n "$desktop_id" ]]; then
    session_file_for "$desktop_id"
    return
  fi

  for name in xfce xfce4 mate cinnamon plasma gnome-classic gnome; do
    if candidate="$(session_file_for "$name" 2>/dev/null)"; then
      desktop_id="$name"
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  for session_dir in /usr/share/xsessions /usr/local/share/xsessions; do
    if [[ -d "$session_dir" ]]; then
      for candidate in "$session_dir"/*.desktop; do
        [[ -f "$candidate" ]] || continue
        desktop_id="$(basename "$candidate" .desktop)"
        printf '%s\n' "$candidate"
        return 0
      done
    fi
  done
  return 1
}

desktop_entry_value() {
  local file="$1"
  local key="$2"
  awk -F= -v key="$key" '$1 == key { print substr($0, index($0, "=") + 1); exit }' "$file"
}

sanitize_exec_line() {
  local cmd="$1"
  local code

  for code in %f %F %u %U %d %D %n %N %i %c %k %v %m; do
    cmd="${cmd//$code/}"
  done

  printf '%s\n' "$cmd" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

session_file="$(select_session_file)"
startup_cmd="$(sanitize_exec_line "$(desktop_entry_value "$session_file" Exec)")"
desktop_names="$(desktop_entry_value "$session_file" DesktopNames)"

if [[ -z "$startup_cmd" ]]; then
  echo "Selected desktop entry has no Exec line: $session_file" >&2
  exit 1
fi

current_desktop="${desktop_names%;}"
current_desktop="${current_desktop//;/:}"
if [[ -z "$current_desktop" ]]; then
  current_desktop="$desktop_id"
fi

unset DBUS_SESSION_BUS_ADDRESS
unset GNOME_SETUP_DISPLAY
unset SESSION_MANAGER
unset WAYLAND_DISPLAY

export DESKTOP_SESSION="$desktop_id"
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export XDG_CURRENT_DESKTOP="$current_desktop"
export XDG_SESSION_DESKTOP="$desktop_id"
export XDG_SESSION_TYPE=x11

if command -v dbus-run-session >/dev/null 2>&1; then
  exec dbus-run-session -- bash -lc "exec $startup_cmd"
fi

exec bash -lc "exec $startup_cmd"
