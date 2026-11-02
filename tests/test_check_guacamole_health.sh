#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

STATE_FILE="$TEST_ROOT/state"
LOG_FILE="$TEST_ROOT/systemctl.log"

cat > "$TEST_ROOT/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  is-active)
    [[ "$(cat "$STATE_FILE")" == "healthy" ]]
    ;;
  restart)
    printf '%s\n' "$*" >> "$LOG_FILE"
    printf 'healthy\n' > "$STATE_FILE"
    ;;
  *)
    exit 2
    ;;
esac
EOF

cat > "$TEST_ROOT/podman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == "exec" ]]
[[ "$(cat "$STATE_FILE")" == "healthy" ]]
EOF

chmod +x "$TEST_ROOT/systemctl" "$TEST_ROOT/podman"
export STATE_FILE LOG_FILE

printf 'healthy\n' > "$STATE_FILE"
SYSTEMCTL_BIN="$TEST_ROOT/systemctl" \
PODMAN_BIN="$TEST_ROOT/podman" \
  "$ROOT_DIR/scripts/check_guacamole_health.sh"
[[ ! -e "$LOG_FILE" ]]

printf 'broken\n' > "$STATE_FILE"
SYSTEMCTL_BIN="$TEST_ROOT/systemctl" \
PODMAN_BIN="$TEST_ROOT/podman" \
RECOVERY_ATTEMPTS=1 \
RECOVERY_DELAY_SECONDS=0 \
  "$ROOT_DIR/scripts/check_guacamole_health.sh"

grep -Fxq 'restart pit-box-guacd.service pit-box-guacamole.service' "$LOG_FILE"
[[ "$(cat "$STATE_FILE")" == "healthy" ]]

echo "Guacamole health-check tests passed."
