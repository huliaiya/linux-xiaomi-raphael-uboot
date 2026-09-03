#!/bin/bash
set -e

SYSTEM_TYPE="${SYSTEM_TYPE:-ubuntu-server}"
DESKTOP_ENV="${DESKTOP_ENV:-}"
DEBIAN_VERSION="${DEBIAN_VERSION:-trixie}"
UBUNTU_VERSION="${UBUNTU_VERSION:-resolute}"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] 📦 安装软件包"

export DEBIAN_FRONTEND=noninteractive

echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ 更新系统包..."
chroot rootdir apt-get update
chroot rootdir apt-get upgrade -y

BASE_PACKAGES="bash-completion sudo apt-utils ssh openssh-server nano network-manager initramfs-tools chrony curl wget locales tzdata iproute2 zram-tools"

if [[ "$SYSTEM_TYPE" == *"debian-"* ]]; then 
    BASE_PACKAGES="bash-completion sudo apt-utils ssh openssh-server nano network-manager initramfs-tools chrony curl wget locales tzdata fonts-wqy-microhei dnsmasq nftables iproute2 zram-tools"
elif [[ "$SYSTEM_TYPE" == *"ubuntu-"* ]]; then
    if [[ "$SYSTEM_TYPE" == *"server"* ]]; then
        BASE_PACKAGES="bash-completion sudo apt-utils ssh openssh-server nano network-manager initramfs-tools chrony curl wget locales tzdata dnsmasq nftables iproute2 zram-tools"
    else
        BASE_PACKAGES="bash-completion sudo apt-utils ssh openssh-server nano network-manager initramfs-tools chrony curl wget locales tzdata dnsmasq nftables iproute2 zram-tools"
    fi
fi

DEVICE_PACKAGES="rmtfs protection-domain-mapper tqftpserv"

if [[ "$SYSTEM_TYPE" != *"server"* ]]; then
    case "$DESKTOP_ENV" in
        "gnome")
            if [[ "$SYSTEM_TYPE" == *"ubuntu-"* ]]; then
                DESKTOP_PACKAGES="ubuntu-desktop"
            elif [[ "$SYSTEM_TYPE" == *"debian-"* ]]; then
                DESKTOP_PACKAGES="gnome"
            fi
            ;;
        "phosh-core")
            DESKTOP_PACKAGES="phosh-core"
            ;;
        "phosh-full")
            DESKTOP_PACKAGES="phosh-full nautilus gnome-calculator gnome-screenshot geary evince eog gnome-text-editor gnome-calendar gnome-weather gnome-maps gnome-notes gnome-software file-roller baobab gnome-contacts "
            ;;
        "phosh-phone")
            DESKTOP_PACKAGES="phosh-phone"
            ;;
        *)
            DESKTOP_PACKAGES=""
            ;;
    esac
else
    DESKTOP_PACKAGES=""
fi

ALL_PACKAGES="$BASE_PACKAGES $DEVICE_PACKAGES $DESKTOP_PACKAGES"

echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ 基础包: $(echo "$BASE_PACKAGES" | tr ' ' ', ')"
echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ 设备包: $(echo "$DEVICE_PACKAGES" | tr ' ' ', ')"
if [ -n "$DESKTOP_PACKAGES" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ 桌面包: $(echo "$DESKTOP_PACKAGES" | tr ' ' ', ')"
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ 开始安装（这可能需要几分钟...）"
chroot rootdir apt-get install -y $ALL_PACKAGES

# 安装星火应用商店
echo "[$(date + '%Y-%m-%d %H:%M:%S')]   └─ 安装星火应用商店"
wget -qO /tmp/spark-key.gpg "https://spark-store.io/spark-store-archive-keyring.gpg" 2>/dev/null || true
if [ -s /tmp/spark-key.gpg ]; then
    cp /tmp/spark-key.gpg rootdir/usr/share/keyrings/spark-store-archive-keyring.gpg
    echo "deb [arch=arm64 signed-by=/usr/share/keyrings/spark-store-archive-keyring.gpg] https://mirrors.sjtug.sjtu.edu.cn/spark-store/debian/ stable main" > rootdir/etc/apt/sources.list.d/spark-store.list
    chroot rootdir apt-get update 2>/dev/null || true
    chroot rootdir apt-get install -y spark-store 2>/dev/null || echo "⚠️ 星火应用商店安装失败，可稍后手动安装"
else
    echo "⚠️ 星火应用商店密钥下载失败，跳过"
fi

# 修改服务配置
sed -i '/ConditionKernelVersion/d' rootdir/lib/systemd/system/pd-mapper.service 2>/dev/null || true

if [ -f "alsa-xiaomi-raphael.deb" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ 安装 ALSA 配置"
    cp alsa-xiaomi-raphael.deb rootdir/tmp/
    chroot rootdir dpkg -i /tmp/alsa-xiaomi-raphael.deb
    rm rootdir/tmp/alsa-xiaomi-raphael.deb
fi

if [[ "$SYSTEM_TYPE" != *"server"* ]]; then
    if [[ "$DESKTOP_ENV" == phosh* ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')]   └─ 启用 Phosh 服务"
        chroot rootdir systemctl enable phosh
    fi
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ 软件包安装完成"
