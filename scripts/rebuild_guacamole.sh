#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT_DIR/scripts/render_remote_desktop_gateway.sh"
"$ROOT_DIR/scripts/install_remote_desktop_gateway.sh"

echo "Guacamole rebuilt."
