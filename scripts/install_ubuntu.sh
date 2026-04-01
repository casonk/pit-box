#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  wireguard \
  wireguard-tools \
  openssh-server \
  qrencode \
  zip \
  iptables \
  ufw

systemctl enable ssh
echo "Ubuntu/Debian dependencies installed."
