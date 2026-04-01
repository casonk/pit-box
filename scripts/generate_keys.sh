#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_DIR="$ROOT_DIR/secrets"

mkdir -p "$SECRETS_DIR"
umask 077

for name in server client; do
  if [[ ! -f "$SECRETS_DIR/${name}.key" ]]; then
    wg genkey | tee "$SECRETS_DIR/${name}.key" | wg pubkey > "$SECRETS_DIR/${name}.pub"
    echo "Generated keys for $name"
  else
    echo "Keys for $name already exist; leaving in place"
  fi
done
