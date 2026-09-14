#!/usr/bin/env bash
# iceoryx + CycloneDDS ROS2 中间件环境脚本
# 所有路径均基于本脚本自身位置推导，可放置于任意目录，无需固定挂载到 /opt。
# 按当前平台(arch)自动选择对应的预编译产物目录 install_<arch>（x86_64 / aarch64）。

# 脚本所在目录（即 iceoryx_cyclone_dds 根目录）
ICX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ROS2 安装目录，可用环境变量覆盖（默认 Humble 位于 /opt/ros/humble）
ROS_DISTRO_DIR="${ROS_DISTRO_DIR:-/opt/ros/humble}"

# 平台检测：uname -m → install_<arch>
ARCH="$(uname -m)"
case "${ARCH}" in
    x86_64|amd64)   ICX_ARCH="x86_64" ;;
    aarch64|arm64)  ICX_ARCH="aarch64" ;;
    *)
        echo "错误：不支持的架构 ${ARCH}（仅支持 x86_64 / aarch64）" >&2
        return 1
        ;;
esac
ICX_INSTALL_DIR="${ICX_DIR}/install_${ICX_ARCH}"
export ICX_ARCH ICX_INSTALL_DIR

if [ ! -f "${ICX_INSTALL_DIR}/setup.bash" ]; then
    echo "错误：找不到 ${ICX_ARCH} 平台的中间件产物 ${ICX_INSTALL_DIR}/setup.bash" >&2
    return 1
fi

source "${ROS_DISTRO_DIR}/setup.sh"
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
source "${ICX_INSTALL_DIR}/setup.bash"
export CYCLONEDDS_URI="${ICX_DIR}/config/cyclonedds.xml"
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
