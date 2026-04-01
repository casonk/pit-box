#!/usr/bin/env bash
set -euo pipefail

if command -v apt-get >/dev/null 2>&1; then
  exec "$(dirname "$0")/install_ubuntu.sh"
elif command -v dnf >/dev/null 2>&1; then
  exec "$(dirname "$0")/install_fedora.sh"
else
  echo "Unsupported distribution. Install WireGuard, OpenSSH, and your firewall tooling manually." >&2
  exit 1
fi
