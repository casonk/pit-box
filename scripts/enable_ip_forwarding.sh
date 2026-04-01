#!/usr/bin/env bash
set -euo pipefail

SYSCTL_FILE="/etc/sysctl.d/99-wireguard-forwarding.conf"

cat > "$SYSCTL_FILE" <<'EOF'
net.ipv4.ip_forward = 1
EOF

sysctl --system
echo "Enabled IPv4 forwarding via $SYSCTL_FILE"
