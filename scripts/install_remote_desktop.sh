#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE="$ROOT_DIR/settings.env"
XRDP_INI="${XRDP_INI:-/etc/xrdp/xrdp.ini}"
XRDP_SESMAN_INI="${XRDP_SESMAN_INI:-/etc/xrdp/sesman.ini}"
XRDP_STARTWM_SOURCE="$ROOT_DIR/configs/remote-desktop/startwm-pit-box.sh"
XRDP_STARTWM_TARGET="/etc/xrdp/startwm-pit-box.sh"
XRDP_STARTWM_ENV="/etc/xrdp/startwm-pit-box.env"
XRDP_DROPIN_DIR="/etc/systemd/system/xrdp.service.d"
XRDP_DROPIN="$XRDP_DROPIN_DIR/10-pit-box-wireguard.conf"

# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/site_registry.sh"

[[ -f "$SETTINGS_FILE" ]] || { echo "Missing settings.env" >&2; exit 1; }
# shellcheck source=/dev/null
source "$SETTINGS_FILE"

: "${REMOTE_DESKTOP_ENABLED:?Missing REMOTE_DESKTOP_ENABLED}"
: "${WG_INTERFACE:?Missing WG_INTERFACE}"
: "${WG_SERVER_TUNNEL_IP:?Missing WG_SERVER_TUNNEL_IP}"
: "${WG_SUBNET_CIDR:?Missing WG_SUBNET_CIDR}"

if [[ "$REMOTE_DESKTOP_ENABLED" != "true" ]]; then
  echo "REMOTE_DESKTOP_ENABLED is not 'true'. Skipping remote desktop installation."
  exit 0
fi

: "${REMOTE_DESKTOP_PORT:?Missing REMOTE_DESKTOP_PORT}"
REMOTE_DESKTOP_BIND_ADDRESS="${REMOTE_DESKTOP_BIND_ADDRESS:-$WG_SERVER_TUNNEL_IP}"

if [[ -z "${REMOTE_DESKTOP_HOSTNAME:-}" ]]; then
  if registry_hostname="$(resolve_registry_hostname "$ROOT_DIR" "pit-box-rdp" 2>/dev/null)" && [[ -n "$registry_hostname" ]]; then
    REMOTE_DESKTOP_HOSTNAME="$registry_hostname"
    export REMOTE_DESKTOP_HOSTNAME
  fi
fi

install_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get install -y xrdp xorgxrdp dbus-x11
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y xrdp xorgxrdp
  else
    echo "Unsupported package manager. Install xrdp and xorgxrdp manually." >&2
    exit 1
  fi
}

desktop_session_exists() {
  local name="$1"
  [[ -n "$name" ]] || return 1
  [[ -f "/usr/share/xsessions/${name}.desktop" || -f "/usr/local/share/xsessions/${name}.desktop" ]]
}

detect_desktop_session() {
  local name session_dir candidate

  if [[ -n "${REMOTE_DESKTOP_SESSION:-}" ]]; then
    desktop_session_exists "$REMOTE_DESKTOP_SESSION" || {
      echo "REMOTE_DESKTOP_SESSION=${REMOTE_DESKTOP_SESSION} has no matching .desktop file in /usr/share/xsessions." >&2
      return 1
    }
    printf '%s\n' "$REMOTE_DESKTOP_SESSION"
    return 0
  fi

  for name in xfce xfce4 mate cinnamon plasma gnome-classic gnome; do
    if desktop_session_exists "$name"; then
      printf '%s\n' "$name"
      return 0
    fi
  done

  for session_dir in /usr/share/xsessions /usr/local/share/xsessions; do
    if [[ -d "$session_dir" ]]; then
      for candidate in "$session_dir"/*.desktop; do
        [[ -f "$candidate" ]] || continue
        basename "$candidate" .desktop
        return 0
      done
    fi
  done

  echo "No X11 desktop session found in /usr/share/xsessions. Install a desktop session package or set REMOTE_DESKTOP_SESSION." >&2
  return 1
}

backup_once() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  [[ -f "${path}.pit-box.bak" ]] || cp "$path" "${path}.pit-box.bak"
}

set_ini_key() {
  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"
  local tmp="${file}.pit-box.tmp"

  awk -v section="$section" -v key="$key" -v value="$value" '
    BEGIN { in_section = 0; done = 0 }
    /^[[:space:]]*\[/ {
      if (in_section && !done) {
        print key "=" value
        done = 1
      }
      in_section = ($0 == "[" section "]")
      print
      next
    }
    in_section && $0 ~ "^[[:space:]]*#?[[:space:]]*" key "[[:space:]]*=" {
      if (!done) {
        print key "=" value
        done = 1
      }
      next
    }
    { print }
    END {
      if (in_section && !done) {
        print key "=" value
      }
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

ensure_xorg_session() {
  local file="$1"
  local tmp="${file}.pit-box.tmp"

  if grep -q '^\[Xorg\][[:space:]]*$' "$file"; then
    return 0
  fi

  awk '
    BEGIN { inserted = 0 }
    /^\[Xvnc\][[:space:]]*$/ && !inserted {
      print "[Xorg]"
      print "name=Xorg"
      print "lib=libxup.so"
      print "username=ask"
      print "password=ask"
      print "port=-1"
      print "code=20"
      print ""
      inserted = 1
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

install_packages

[[ -f "$XRDP_INI" ]] || {
  echo "Missing $XRDP_INI after package install; cannot configure xrdp." >&2
  exit 1
}
[[ -f "$XRDP_SESMAN_INI" ]] || {
  echo "Missing $XRDP_SESMAN_INI after package install; cannot configure xrdp session startup." >&2
  exit 1
}
[[ -x "$XRDP_STARTWM_SOURCE" || -f "$XRDP_STARTWM_SOURCE" ]] || {
  echo "Missing $XRDP_STARTWM_SOURCE; cannot configure xrdp session startup." >&2
  exit 1
}

backup_once "$XRDP_INI"
backup_once "$XRDP_SESMAN_INI"
set_ini_key "$XRDP_INI" Globals port "tcp://${REMOTE_DESKTOP_BIND_ADDRESS}:${REMOTE_DESKTOP_PORT}"
set_ini_key "$XRDP_INI" Globals crypt_level high
set_ini_key "$XRDP_INI" Globals autorun Xorg
ensure_xorg_session "$XRDP_INI"

REMOTE_DESKTOP_SESSION="$(detect_desktop_session)"
export REMOTE_DESKTOP_SESSION
install -m 0755 "$XRDP_STARTWM_SOURCE" "$XRDP_STARTWM_TARGET"
cat > "$XRDP_STARTWM_ENV" <<EOF
PIT_BOX_XRDP_DESKTOP_SESSION=${REMOTE_DESKTOP_SESSION}
EOF
chmod 0644 "$XRDP_STARTWM_ENV"
set_ini_key "$XRDP_SESMAN_INI" Globals EnableUserWindowManager false
set_ini_key "$XRDP_SESMAN_INI" Globals DefaultWindowManager "$XRDP_STARTWM_TARGET"

mkdir -p "$XRDP_DROPIN_DIR"
cat > "$XRDP_DROPIN" <<EOF
[Unit]
After=network-online.target wg-quick@${WG_INTERFACE}.service
Wants=network-online.target wg-quick@${WG_INTERFACE}.service
EOF

systemctl daemon-reload
systemctl enable --now xrdp-sesman 2>/dev/null || true
systemctl enable --now xrdp
systemctl restart xrdp-sesman 2>/dev/null || true
systemctl restart xrdp

echo "Remote desktop installed and started."
echo "  RDP target: ${REMOTE_DESKTOP_HOSTNAME:-$WG_SERVER_TUNNEL_IP}:${REMOTE_DESKTOP_PORT}"
echo "  Bind address: ${REMOTE_DESKTOP_BIND_ADDRESS}"
echo "  Desktop session: ${REMOTE_DESKTOP_SESSION}"
echo "Only reachable over the WireGuard VPN when firewall rules are applied."
echo "Run sudo ./scripts/configure_firewall.sh to allow RDP only on ${WG_INTERFACE}."
