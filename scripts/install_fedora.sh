#!/usr/bin/env bash
set -euo pipefail

dnf install -y \
  wireguard-tools \
  openssh-server \
  qrencode \
  zip \
  iptables \
  firewalld

systemctl enable --now sshd
systemctl enable --now firewalld
echo "Fedora dependencies installed."
