# 系统类型到基础设置的映射
system_config() {
  case "$1" in
    "debian-server")
      echo "DEBIAN_VERSION=${DEBIAN_VERSION:-trixie}"
      echo "IMAGE_SIZE=3G"
      echo "IS_DESKTOP=false"
      echo "DESKTOP_ENV="
      ;;
    "debian-gnome")
      echo "DEBIAN_VERSION=${DEBIAN_VERSION:-trixie}"
      echo "IMAGE_SIZE=8G"
      echo "IS_DESKTOP=true"
      echo "DESKTOP_ENV=gnome"
      ;;
    "debian-phosh")
      echo "DEBIAN_VERSION=${DEBIAN_VERSION:-trixie}"
      echo "IMAGE_SIZE=8G"
      echo "IS_DESKTOP=true"
      echo "DESKTOP_ENV=$2"
      ;;
    "ubuntu-server")
      echo "UBUNTU_VERSION=${UBUNTU_VERSION:-resolute}"
      echo "IMAGE_SIZE=3G"
      echo "IS_DESKTOP=false"
      echo "DESKTOP_ENV="
      ;;
    "ubuntu-gnome")
      echo "UBUNTU_VERSION=${UBUNTU_VERSION:-resolute}"
      echo "IMAGE_SIZE=8G"
      echo "IS_DESKTOP=true"
      echo "DESKTOP_ENV=gnome"
      ;;
    "ubuntu-phosh")
      echo "UBUNTU_VERSION=${UBUNTU_VERSION:-resolute}"
      echo "IMAGE_SIZE=8G"
      echo "IS_DESKTOP=true"
      echo "DESKTOP_ENV=$2"
      ;;
  esac
}

# ============ GPT 分区方案（Nura / postmarketOS） ============
# 镜像采用 GPT 布局: p1 = boot (fat32, ESP) + p2 = root (ext4)
# 参考: pmbootstrap device-xiaomi-raphael (deviceinfo_rootfs_image_sector_size="4096")
export BOOT_SIZE="${BOOT_SIZE:-256M}"                        # boot 分区大小
export BOOT_LABEL="${BOOT_LABEL:-Boot}"                 # boot 文件系统标签
export ROOT_LABEL="${ROOT_LABEL:-Root}"                 # root 文件系统标签
export SECTOR_SIZE="${SECTOR_SIZE:-4096}"                    # 镜像逻辑扇区大小 (UFS)
export BOOT_PART_START="${BOOT_PART_START:-2048}"            # boot 分区起始扇区 (8MiB 对齐)
export ROOT_PART_TYPE="${ROOT_PART_TYPE:-b921b045-1df0-41c3-af44-4c6f280d3fae}"  # DPS arm64 root
export ESP_PART_TYPE="${ESP_PART_TYPE:-c12a7328-f81f-11d2-ba4b-00a0c93ec93b}"    # ESP
export BOOT_VOLID="${BOOT_VOLID:-1BF4A32B}"                  # boot 分区卷序列号 (UUID: 1BF4-A32B)

# 卸载镜像的所有挂载点。findmnt 按挂载顺序输出，逆序处理可保证先卸载子挂载。
cleanup_build_mounts() {
    local rootdir_path mount_target mount_table status=0 i
    local -a mount_targets=()
    rootdir_path=$(readlink -f "${ROOTDIR:-rootdir}")

    if [ -z "$rootdir_path" ] || [ "$rootdir_path" = "/" ]; then
        echo "拒绝清理无效的镜像挂载目录: $rootdir_path" >&2
        return 1
    fi

    if ! mount_table=$(findmnt --list --noheadings --output TARGET); then
        echo "无法读取挂载列表，禁止清理镜像目录" >&2
        return 1
    fi
    while IFS= read -r mount_target; do
        case "$mount_target" in
            "$rootdir_path"|"$rootdir_path"/*)
                mount_targets+=("$mount_target")
                ;;
        esac
    done <<< "$mount_table"

    for ((i=${#mount_targets[@]}-1; i>=0; i--)); do
        if ! umount "${mount_targets[$i]}"; then
            echo "无法卸载 ${mount_targets[$i]}，禁止删除镜像目录或释放 loop 设备" >&2
            status=1
        fi
    done

    # 删除 rootdir 前必须确保没有未识别或卸载失败的挂载。
    if ! mount_table=$(findmnt --list --noheadings --output TARGET); then
        echo "无法复查挂载列表，禁止清理镜像目录" >&2
        return 1
    fi
    while IFS= read -r mount_target; do
        case "$mount_target" in
            "$rootdir_path"|"$rootdir_path"/*)
                echo "仍存在镜像挂载: $mount_target" >&2
                status=1
                ;;
        esac
    done <<< "$mount_table"

    return "$status"
}

# 只释放与当前镜像关联的 loop 设备，不能使用 losetup -D 影响其他任务。
cleanup_image_loop() {
    local image_name="${IMAGE_NAME:-rootfs.img}"
    local image_path loop_dev loop_devices status=0

    [ -f "$image_name" ] || return 0
    image_path=$(readlink -f "$image_name")
    if ! loop_devices=$(losetup -j "$image_path" -l --raw -n -O NAME); then
        echo "无法查询当前镜像的 loop 设备: $image_path" >&2
        return 1
    fi

    while IFS= read -r loop_dev; do
        [ -n "$loop_dev" ] || continue
        if ! losetup -d "$loop_dev"; then
            echo "无法释放 loop 设备: $loop_dev" >&2
            status=1
        fi
    done <<< "$loop_devices"

    return "$status"
}

cleanup_build() {
    cleanup_build_mounts || return 1
    cleanup_image_loop
}
