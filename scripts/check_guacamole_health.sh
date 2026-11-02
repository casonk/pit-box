#!/usr/bin/env bash
set -euo pipefail

SYSTEMCTL_BIN="${SYSTEMCTL_BIN:-systemctl}"
PODMAN_BIN="${PODMAN_BIN:-podman}"
GUACD_SERVICE="${GUACD_SERVICE:-pit-box-guacd.service}"
GUACAMOLE_SERVICE="${GUACAMOLE_SERVICE:-pit-box-guacamole.service}"
GUACAMOLE_CONTAINER="${GUACAMOLE_CONTAINER:-pit-box-guacamole}"
GUACD_HOSTNAME="${GUACD_HOSTNAME:-pit-box-guacd}"
RECOVERY_ATTEMPTS="${RECOVERY_ATTEMPTS:-30}"
RECOVERY_DELAY_SECONDS="${RECOVERY_DELAY_SECONDS:-1}"

gateway_healthy() {
  "$SYSTEMCTL_BIN" is-active --quiet "$GUACD_SERVICE" "$GUACAMOLE_SERVICE" \
    && "$PODMAN_BIN" exec "$GUACAMOLE_CONTAINER" \
      getent hosts "$GUACD_HOSTNAME" >/dev/null 2>&1
}

if gateway_healthy; then
  exit 0
fi

echo "Guacamole gateway health check failed; restarting ${GUACD_SERVICE} and ${GUACAMOLE_SERVICE}." >&2
"$SYSTEMCTL_BIN" restart "$GUACD_SERVICE" "$GUACAMOLE_SERVICE"

for ((attempt = 1; attempt <= RECOVERY_ATTEMPTS; attempt += 1)); do
  if gateway_healthy; then
    echo "Guacamole gateway recovered after paired restart."
    exit 0
  fi
  sleep "$RECOVERY_DELAY_SECONDS"
done

echo "Guacamole gateway did not recover after paired restart." >&2
exit 1
