#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE="$ROOT_DIR/settings.env"
SECRETS_DIR="$ROOT_DIR/secrets"
BUILD_DIR="$ROOT_DIR/build"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --settings) SETTINGS_FILE="$2"; shift 2;;
    *) echo "Unknown argument: $1" >&2; exit 1;;
  esac
done
# Resolve to absolute path so systemd ExecStart lines use a stable path.
[[ "$SETTINGS_FILE" = /* ]] || SETTINGS_FILE="$ROOT_DIR/$SETTINGS_FILE"

# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/site_registry.sh"

require_file() {
  local f="$1"
  [[ -f "$f" ]] || { echo "Missing required file: $f" >&2; exit 1; }
}

require_var() {
  local v="$1"
  [[ -n "${!v:-}" ]] || { echo "Missing required variable: $v" >&2; exit 1; }
}

require_file "$SETTINGS_FILE"
require_file "$SECRETS_DIR/server.key"
require_file "$SECRETS_DIR/server.pub"
require_file "$SECRETS_DIR/client.key"
require_file "$SECRETS_DIR/client.pub"

# shellcheck source=/dev/null
source "$SETTINGS_FILE"

WEBTERM_ENV_SUFFIX="${WEBTERM_ENV_SUFFIX:-}"
WEBTERM_TMUX_SESSION="${WEBTERM_TMUX_SESSION:-pit-box}"
WEBTERM_SIBLING_URL="${WEBTERM_SIBLING_URL:-}"
# Auto-derive env label from suffix when not explicitly set.
if [[ -n "${WEBTERM_ENV_LABEL:-}" ]]; then
  :
elif [[ -n "$WEBTERM_ENV_SUFFIX" ]]; then
  WEBTERM_ENV_LABEL="${WEBTERM_ENV_SUFFIX#-}"
else
  WEBTERM_ENV_LABEL="prod"
fi

PRIVATE_DNS_REQUIRED=false
if [[ "${WEBTERM_ENABLED:-false}" == "true" ]]; then
  populate_site_hostname "$ROOT_DIR" "pit-box-webterm" WEBTERM_HOSTNAME
  PRIVATE_DNS_REQUIRED=true
fi
if [[ "${COCKPIT_ENABLED:-false}" == "true" ]]; then
  populate_site_hostname "$ROOT_DIR" "pit-box-cockpit" COCKPIT_HOSTNAME
  PRIVATE_DNS_REQUIRED=true
fi
if [[ "${REMOTE_DESKTOP_ENABLED:-false}" == "true" ]]; then
  if [[ -z "${REMOTE_DESKTOP_HOSTNAME:-}" ]]; then
    if registry_hostname="$(resolve_registry_hostname "$ROOT_DIR" "pit-box-rdp" 2>/dev/null)" && [[ -n "$registry_hostname" ]]; then
      REMOTE_DESKTOP_HOSTNAME="$registry_hostname"
      export REMOTE_DESKTOP_HOSTNAME
    fi
  fi
  if [[ -n "${REMOTE_DESKTOP_HOSTNAME:-}" ]]; then
    PRIVATE_DNS_REQUIRED=true
  fi
fi
if [[ "${REMOTE_DESKTOP_WEB_ENABLED:-false}" == "true" ]]; then
  if [[ -z "${REMOTE_DESKTOP_WEB_HOSTNAME:-}" ]]; then
    populate_site_hostname "$ROOT_DIR" "pit-box-remote-desktop" REMOTE_DESKTOP_WEB_HOSTNAME
  fi
  PRIVATE_DNS_REQUIRED=true
fi

for var in SERVER_NAME CLIENT_NAME WG_INTERFACE WG_SERVER_IP WG_SERVER_TUNNEL_IP WG_CLIENT_IP WG_CLIENT_TUNNEL_IP WG_SUBNET_CIDR LAN_IFACE LAN_SUBNET_CIDR LAN_DNS_SERVER WG_LISTEN_PORT PUBLIC_ENDPOINT ROUTING_MODE PERSISTENT_KEEPALIVE; do
  require_var "$var"
done

mkdir -p "$BUILD_DIR/server" "$BUILD_DIR/client" "$BUILD_DIR/ssh"

SERVER_PRIVATE_KEY="$(cat "$SECRETS_DIR/server.key")"
SERVER_PUBLIC_KEY="$(cat "$SECRETS_DIR/server.pub")"
CLIENT_PRIVATE_KEY="$(cat "$SECRETS_DIR/client.key")"
CLIENT_PUBLIC_KEY="$(cat "$SECRETS_DIR/client.pub")"

# When private hostnames are enabled, the client uses the server as its
# VPN-scoped DNS resolver so wiring-harness or pit-box DNS records resolve over
# the tunnel.
if [[ "$PRIVATE_DNS_REQUIRED" == "true" ]]; then
  CLIENT_DNS="$WG_SERVER_TUNNEL_IP"
else
  CLIENT_DNS="$LAN_DNS_SERVER"
fi

case "$ROUTING_MODE" in
  server-only)
    CLIENT_ALLOWED_IPS="$WG_SUBNET_CIDR"
    ;;
  lan)
    CLIENT_ALLOWED_IPS="$WG_SUBNET_CIDR, $LAN_SUBNET_CIDR"
    ;;
  full-tunnel)
    CLIENT_ALLOWED_IPS="0.0.0.0/0, ::/0"
    ;;
  *)
    echo "Invalid ROUTING_MODE: $ROUTING_MODE" >&2
    exit 1
    ;;
esac

cat > "$BUILD_DIR/server/wg0.conf" <<EOF
[Interface]
Address = $WG_SERVER_IP
ListenPort = $WG_LISTEN_PORT
PrivateKey = $SERVER_PRIVATE_KEY

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = ${WG_CLIENT_TUNNEL_IP}/32
EOF

cat > "$BUILD_DIR/client/iphone.conf" <<EOF
[Interface]
Address = $WG_CLIENT_IP
PrivateKey = $CLIENT_PRIVATE_KEY
DNS = $CLIENT_DNS

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $PUBLIC_ENDPOINT
AllowedIPs = $CLIENT_ALLOWED_IPS
PersistentKeepalive = $PERSISTENT_KEEPALIVE
EOF

cat > "$BUILD_DIR/ssh/sshd_config.snippet" <<'EOF'
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
ClientAliveInterval 30
ClientAliveCountMax 6
EOF

echo "Rendered build/server/wg0.conf"
echo "Rendered build/client/iphone.conf"
echo "Rendered build/ssh/sshd_config.snippet"

if [[ "${WEBTERM_ENABLED:-false}" == "true" ]]; then
  : "${WEBTERM_PORT:?WEBTERM_ENABLED=true but WEBTERM_PORT is not set}"
  : "${WEBTERM_HOSTNAME:?WEBTERM_ENABLED=true but WEBTERM_HOSTNAME is not set}"
  : "${WEBTERM_USER:?WEBTERM_ENABLED=true but WEBTERM_USER is not set}"
  : "${CADDY_CERTS_DIR:?WEBTERM_ENABLED=true but CADDY_CERTS_DIR is not set}"
  WEBTERM_API_PORT=$((WEBTERM_PORT + 1))

  # Build optional env args for the API ExecStart line.
  _api_env_args="--env-label ${WEBTERM_ENV_LABEL}"
  [[ -n "$WEBTERM_SIBLING_URL" ]] && _api_env_args="${_api_env_args} --sibling-url ${WEBTERM_SIBLING_URL}"
  [[ "${COCKPIT_ENABLED:-false}" == "true" && -n "${COCKPIT_HOSTNAME:-}" ]] && \
    _api_env_args="${_api_env_args} --cockpit-url https://${COCKPIT_HOSTNAME}"
  [[ "${REMOTE_DESKTOP_WEB_ENABLED:-false}" == "true" && -n "${REMOTE_DESKTOP_WEB_HOSTNAME:-}" ]] && \
    _api_env_args="${_api_env_args} --desktop-url https://${REMOTE_DESKTOP_WEB_HOSTNAME}"

  mkdir -p "$BUILD_DIR/webterm"
  cat > "$BUILD_DIR/webterm/ttyd${WEBTERM_ENV_SUFFIX}.service" <<EOF
[Unit]
Description=ttyd - Web Terminal over WireGuard VPN${WEBTERM_ENV_SUFFIX}
Documentation=https://github.com/tsl0922/ttyd
After=network-online.target wg-quick@${WG_INTERFACE}.service
Wants=network-online.target

[Service]
Type=simple
User=${WEBTERM_USER}
# Loopback-only: Caddy proxies from the VPN interface, ttyd is not directly reachable.
# ttyd_session.sh creates a grouped tmux session per connection so each browser tab
# tracks its active window independently.
ExecStart=/usr/bin/ttyd --writable --interface 127.0.0.1 --port ${WEBTERM_PORT} --ping-interval 30 /etc/pit-box${WEBTERM_ENV_SUFFIX}/ttyd_session.sh ${WEBTERM_TMUX_SESSION}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  echo "Rendered build/webterm/ttyd${WEBTERM_ENV_SUFFIX}.service"

  cat > "$BUILD_DIR/webterm/pit-box-api${WEBTERM_ENV_SUFFIX}.service" <<EOF
[Unit]
Description=pit-box web terminal window API${WEBTERM_ENV_SUFFIX}
After=network-online.target ttyd${WEBTERM_ENV_SUFFIX}.service
Wants=network-online.target

[Service]
Type=simple
User=${WEBTERM_USER}
ExecStart=/usr/bin/python3 /etc/pit-box${WEBTERM_ENV_SUFFIX}/pit_box_api.py --port ${WEBTERM_API_PORT} --session ${WEBTERM_TMUX_SESSION} --rebuild-script ${ROOT_DIR}/scripts/rebuild_webservices.sh --settings-file ${SETTINGS_FILE} ${_api_env_args}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  echo "Rendered build/webterm/pit-box-api${WEBTERM_ENV_SUFFIX}.service"

  cat > "$BUILD_DIR/webterm/caddy-webterm${WEBTERM_ENV_SUFFIX}.caddy" <<EOF
https://${WEBTERM_HOSTNAME} {
	tls ${CADDY_CERTS_DIR}/server.crt ${CADDY_CERTS_DIR}/server.key {
		client_auth {
			mode require_and_verify
			trust_pool file ${CADDY_CERTS_DIR}/ca.crt
		}
	}

	encode zstd gzip

	@term_ttyd path /term/token /term/ws
	handle @term_ttyd {
		uri strip_prefix /term
		reverse_proxy 127.0.0.1:${WEBTERM_PORT}
	}

	@home path /
	handle @home {
		header Cache-Control "no-store"
		root * /etc/pit-box${WEBTERM_ENV_SUFFIX}/webterm
		rewrite * /home.html
		file_server
	}

	@term_slash path /term/
	handle @term_slash {
		redir * /term 308
	}

	@term path /term
	handle @term {
		header Cache-Control "no-store"
		root * /etc/pit-box${WEBTERM_ENV_SUFFIX}/webterm
		rewrite * /index.html
		file_server
	}

	@api path /api/*
	handle @api {
		reverse_proxy 127.0.0.1:${WEBTERM_API_PORT}
	}

	handle {
		reverse_proxy 127.0.0.1:${WEBTERM_PORT}
	}

	header {
		X-Content-Type-Options "nosniff"
		X-Frame-Options "SAMEORIGIN"
		Referrer-Policy "no-referrer"
	}
}
EOF
  echo "Rendered build/webterm/caddy-webterm${WEBTERM_ENV_SUFFIX}.caddy"

  DNS_ADDRESSES="address=/${WEBTERM_HOSTNAME}/${WG_SERVER_TUNNEL_IP}"
  if [[ "${COCKPIT_ENABLED:-false}" == "true" ]]; then
    : "${COCKPIT_HOSTNAME:?COCKPIT_ENABLED=true but COCKPIT_HOSTNAME is not set}"
    DNS_ADDRESSES="${DNS_ADDRESSES}"$'\n'"address=/${COCKPIT_HOSTNAME}/${WG_SERVER_TUNNEL_IP}"
  fi
  if [[ "${REMOTE_DESKTOP_ENABLED:-false}" == "true" && -n "${REMOTE_DESKTOP_HOSTNAME:-}" ]]; then
    DNS_ADDRESSES="${DNS_ADDRESSES}"$'\n'"address=/${REMOTE_DESKTOP_HOSTNAME}/${WG_SERVER_TUNNEL_IP}"
  fi
  if [[ "${REMOTE_DESKTOP_WEB_ENABLED:-false}" == "true" && -n "${REMOTE_DESKTOP_WEB_HOSTNAME:-}" ]]; then
    DNS_ADDRESSES="${DNS_ADDRESSES}"$'\n'"address=/${REMOTE_DESKTOP_WEB_HOSTNAME}/${WG_SERVER_TUNNEL_IP}"
  fi

  cat > "$BUILD_DIR/webterm/dnsmasq-vpn${WEBTERM_ENV_SUFFIX}.conf" <<EOF
interface=${WG_INTERFACE}
bind-dynamic
listen-address=${WG_SERVER_TUNNEL_IP}
no-dhcp-interface=${WG_INTERFACE}
server=${LAN_DNS_SERVER}
${DNS_ADDRESSES}
EOF
  echo "Rendered build/webterm/dnsmasq-vpn${WEBTERM_ENV_SUFFIX}.conf"
fi

if [[ "${COCKPIT_ENABLED:-false}" == "true" ]]; then
  : "${COCKPIT_HOSTNAME:?COCKPIT_ENABLED=true but COCKPIT_HOSTNAME is not set}"
  : "${CADDY_CERTS_DIR:?COCKPIT_ENABLED=true but CADDY_CERTS_DIR is not set}"
  COCKPIT_PORT="${COCKPIT_PORT:-9090}"
  mkdir -p "$BUILD_DIR/cockpit"
  cat > "$BUILD_DIR/cockpit/caddy-cockpit${WEBTERM_ENV_SUFFIX}.caddy" <<EOF
https://${COCKPIT_HOSTNAME} {
	tls ${CADDY_CERTS_DIR}/server.crt ${CADDY_CERTS_DIR}/server.key {
		client_auth {
			mode require_and_verify
			trust_pool file ${CADDY_CERTS_DIR}/ca.crt
		}
	}

	encode zstd gzip

	reverse_proxy https://localhost:${COCKPIT_PORT} {
		transport http {
			tls_insecure_skip_verify
		}
		header_up Host localhost:${COCKPIT_PORT}
		header_up X-Forwarded-Proto https
	}

	header {
		X-Content-Type-Options "nosniff"
		Referrer-Policy "no-referrer"
	}
}
EOF
  echo "Rendered build/cockpit/caddy-cockpit${WEBTERM_ENV_SUFFIX}.caddy"
fi
