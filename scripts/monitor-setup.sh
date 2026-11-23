#!/usr/bin/env bash
# Sets up the Ubuntu 24.04 monitoring sensor:
#   - static IP on the LabNet interface (no gateway; internet stays on NAT)
#   - Docker from Ubuntu's repository
#   - Wireshark (linuxserver.io image) with host networking and raw-capture rights
# Usage: sudo ./monitor-setup.sh [labnet-interface] [ip/prefix]
set -euo pipefail

IFACE="${1:-enp0s8}"
ADDR="${2:-10.10.10.20/24}"

echo "[1/3] LabNet profile on ${IFACE} -> ${ADDR}"
if ! nmcli -t -f NAME con show | grep -qx labnet; then
  nmcli con add type ethernet ifname "${IFACE}" con-name labnet \
    ipv4.method manual ipv4.addresses "${ADDR}" ipv6.method disabled
fi
nmcli con up labnet

echo "[2/3] Installing Docker"
apt-get update
apt-get install -y docker.io
systemctl enable --now docker

echo "[3/3] Starting Wireshark container"
if ! docker ps -a --format '{{.Names}}' | grep -qx wireshark; then
  docker run -d --name wireshark --net host \
    --cap-add net_admin --cap-add net_raw \
    --restart unless-stopped lscr.io/linuxserver/wireshark
fi

docker ps --filter name=wireshark
echo "Done. Open http://localhost:3000 in Firefox and capture on ${IFACE}."
