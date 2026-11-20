#!/bin/bash
set -e

HOSTNAME="${HOSTNAME:-huliboot}"
DEVICE_NAME="${DEVICE_NAME:-huliboot}"
NAMESERVER="${NAMESERVER:-223.5.5.5}"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🌐 配置网络和主机名"

rm -f rootdir/etc/resolv.conf
touch rootdir/etc/resolv.conf

echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ 主机名: ${HOSTNAME}"
echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ 设备名: ${DEVICE_NAME}"
echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ DNS: ${NAMESERVER}"

echo "nameserver ${NAMESERVER}" > rootdir/etc/resolv.conf
echo "${HOSTNAME}" > rootdir/etc/hostname
echo "PRETTY_HOSTNAME=${DEVICE_NAME}" > rootdir/etc/machine-info
echo "127.0.0.1 localhost
127.0.1.1 ${HOSTNAME}" > rootdir/etc/hosts

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ 网络配置完成"