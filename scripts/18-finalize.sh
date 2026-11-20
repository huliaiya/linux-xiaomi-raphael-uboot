#!/bin/bash
set -e

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
. "$SCRIPT_DIR/config/build-config.sh"

IMAGE_NAME="${IMAGE_NAME:-rootfs.img}"
IMAGE_UUID="${IMAGE_UUID:-ee8d3593-59b1-480e-a3b6-4fefb17ee7d8}"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] 📦 卸载并完成镜像"

echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ 卸载挂载点..."
cleanup_build_mounts

rm -d rootdir 2>/dev/null || true

echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ 检查 root 分区 (p2) 并设置固定 UUID..."
LOOP_DEV=$(losetup -j "$(readlink -f "${IMAGE_NAME}")" -l --raw -n -O NAME | head -1)
if [ -n "${LOOP_DEV}" ] && [ -e "${LOOP_DEV}p2" ]; then
    e2fsck -f -y ${LOOP_DEV}p2
    tune2fs -U ${IMAGE_UUID} ${LOOP_DEV}p2
    echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ 卸载当前镜像的 loop 设备"
    cleanup_image_loop
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  未找到 ${IMAGE_NAME} 对应的 loop 设备, 跳过 UUID 设置"
fi

echo ""
echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ Boot cmdline 参考: root=UUID=${IMAGE_UUID}"

echo ""
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ 镜像完成"
