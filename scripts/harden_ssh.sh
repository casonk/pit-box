#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SNIPPET_SOURCE="$ROOT_DIR/build/ssh/sshd_config.snippet"
SNIPPET_TARGET="/etc/ssh/sshd_config.d/90-wireguard-hardening.conf"

if [[ ! -f "$SNIPPET_SOURCE" ]]; then
  echo "Missing rendered SSH snippet: $SNIPPET_SOURCE" >&2
  echo "Run ./scripts/render_configs.sh first." >&2
  exit 1
fi

mkdir -p /etc/ssh/sshd_config.d
cp "$SNIPPET_SOURCE" "$SNIPPET_TARGET"

if command -v sshd >/dev/null 2>&1; then
  sshd -t
fi

if systemctl list-unit-files | grep -q '^sshd\.service'; then
  systemctl restart sshd
elif systemctl list-unit-files | grep -q '^ssh\.service'; then
  systemctl restart ssh
else
  echo "SSH service unit not found. Validate manually." >&2
fi

echo "Installed SSH hardening snippet to $SNIPPET_TARGET"
