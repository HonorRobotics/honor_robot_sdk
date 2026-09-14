#!/bin/bash

# Honor Robot SDK - common message packages build script
# Reference: internal common repo build.sh (cmake + make)
# Usage(与工程约定一致,通常由顶层 honor_robot_sdk/build.sh 调用,也可单独编译):
#   CROSS_COMPILE=1 ./build.sh all        # nvidia 交叉编译
#   CROSS_COMPILE=rk3588s ./build.sh all  # rockchip 交叉编译
#   ./build.sh all                        # 非交叉编译(x86)
#   ./build.sh clean                      # 清理
# Environment variables:
#   CROSS_COMPILE        # 1(l4t) | rk3588s | aarch64-poky-linux- (留空=x86本机)
#   BUILD_DIST           # 安装根目录(默认 $PWD;整体编译时顶层设为 out/)

WS=$(cd $(dirname $0);pwd)

if [ -v BUILD_DIST ]; then
    INSTALL_DIR="$BUILD_DIST"
else
    INSTALL_DIR=$PWD
fi

BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[32m'
WHITE='\033[34m'
YELLOW='\033[33m'
NO_COLOR='\033[0m'

function info() {
    (>&2 echo -e "[${WHITE}${BOLD} INFO ${NO_COLOR}] $*")
}

function error() {
    (>&2 echo -e "[${RED} ERROR ${NO_COLOR}] $*")
}

function warning() {
    (>&2 echo -e "[${YELLOW} WARNING ${NO_COLOR}] $*")
}

function ok() {
    (>&2 echo -e "[${GREEN}${BOLD} OK ${NO_COLOR}] $*")
}

function print_delim() {
    echo '=================================================='
}

function get_now() {
    echo $(date +%s)
}

function print_time() {
    END_TIME=$(get_now)
    ELAPSED_TIME=$(echo "$END_TIME - $START_TIME" | bc -l)
    MESSAGE="Took ${ELAPSED_TIME} seconds"
    info "${MESSAGE}"
}

function success() {
    print_delim
    ok "$1"
    print_time
    print_delim
}

function fail() {
    print_delim
    error "$1"
    print_time
    print_delim
}

function clean() {
    rm -rf build build_dist
}

function build_make() {
    MAX_CPU_NUM=$(nproc)
    cd ${WS}/build
    make -j$[${MAX_CPU_NUM}-1] install

    if [ $? -eq 0 ]; then
        success 'Build passed! Message packages compiled successfully.'
        # raw cmake+make 的 ament_cmake 只生成 share/<pkg>/local_setup.bash,
        # 不生成顶层 setup.bash(那是 colcon 工作空间才有)。这里补一个:source 基础
        # ROS + 本 prefix 下所有消息包,等效 colcon 工作空间的顶层 setup.bash。
        cat > "${INSTALL_DIR}/build_dist/common/setup.bash" <<'EOF'
#!/usr/bin/env bash
# 由 common/build.sh 生成。source 基础 ROS + 本 prefix 下所有消息包。
# local_setup.sh 自带 ament_append_* 函数,不依赖基础 ROS,可独立 source。
# 注意:per-package local_setup.bash 只更新 AMENT_PREFIX_PATH/PATH/PYTHONPATH 等,
# 不设置 CMAKE_PREFIX_PATH;而 find_package 靠 CMAKE_PREFIX_PATH 定位 *Config.cmake。
# 故此处显式把本 prefix 加进 CMAKE_PREFIX_PATH,让下游(example)能 find_package 到消息包。
# 变量均加 _COMMON_ 前缀,避免被 source 嵌套(examples 会 source 本文件)时互相 clobber。

_COMMON_PREFIX="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1) 基础 ROS(交叉编译产物在 target 上运行,/opt/ros/humble 即正确路径)
_COMMON_BASE_ROS="/opt/ros/humble/setup.bash"
if [ -f "$_COMMON_BASE_ROS" ]; then
    source "$_COMMON_BASE_ROS"
else
    echo "[common/setup.bash] base ROS not found at $_COMMON_BASE_ROS (already sourced? ok)" >&2
fi

# 2) 本 prefix 加入 CMAKE_PREFIX_PATH(find_package 依赖)
case ":${CMAKE_PREFIX_PATH}:" in
    *:"$_COMMON_PREFIX":*) ;;
    *) export CMAKE_PREFIX_PATH="${_COMMON_PREFIX}${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}" ;;
esac

# 3) 本 prefix 下所有 ament 包的 local_setup.bash(各包自处理 AMENT_CURRENT_PREFIX)
for _COMMON_PKG in "$_COMMON_PREFIX"/share/*/local_setup.bash; do
    [ -f "$_COMMON_PKG" ] && source "$_COMMON_PKG"
done
unset _COMMON_PKG _COMMON_BASE_ROS _COMMON_PREFIX
EOF
        info "Run 'source ${INSTALL_DIR}/build_dist/common/setup.bash' to use the packages."
        exit 0
    else
        fail 'Build failed!'
        exit 1
    fi
}

function build() {
    if [ -v BUILD_OFFLINE ]; then
        rm -rf ${WS}/build
        echo "BUILD_OFFLINE: 1"
    else
        echo "BUILD_OFFLINE: 0"
    fi
    mkdir -p ${WS}/build && cd ${WS}/build

    ROS_SETUP_PATH="/opt/ros/humble/setup.bash"
    if [ -z "$CROSS_COMPILE" ]; then
        # build for X86
        source $ROS_SETUP_PATH
    elif [ "$CROSS_COMPILE" = "aarch64-poky-linux-" ]; then
        # build for Rockchip
        if [[ -z "${BUILD_OFFLINE:-}" ]]; then
            source /opt/poky/5.0.12/environment-setup-cortexa76-cortexa55-poky-linux
            source /opt/poky/5.0.12/sysroots/cortexa76-cortexa55-poky-linux/$ROS_SETUP_PATH
        fi
        EXTRA_OPTIONS=" -DPYTHON_EXECUTABLE=${OECORE_NATIVE_SYSROOT}/usr/bin/python3  \
                        -DPYTHON_INCLUDE_DIR=${OECORE_NATIVE_SYSROOT}/usr/include/python3.12 \
                        -DPYTHON_LIBRARY=${OECORE_NATIVE_SYSROOT}/usr/lib/libpython3.12.so \
                        -DPython_NumPy_INCLUDE_DIR=${OECORE_NATIVE_SYSROOT}/usr/lib/python3.12/site-packages/numpy/core/include "
    elif [ "$CROSS_COMPILE" = "rk3588s" ]; then
        # build for Rockchip rk3588s
        source /rk3588s/sysroot/$SDK_PATH$ROS_SETUP_PATH
        EXTRA_OPTIONS=" -DCMAKE_TOOLCHAIN_FILE=/rk3588s/Toolchain_aarch64_rk3588s.cmake"
    elif [ "$CROSS_COMPILE" = "l4t" ] || [ "$CROSS_COMPILE" = "1" ]; then
        # nvidia Jetson (l4t): 显式指向 /l4t/targetfs 并剔除残缺的 /opt/ros/humble
        # (与 example/cpp/build.sh 一致,避免残缺 ROS 干扰 rclcpp 传递依赖查找)
        # 工程约定 CROSS_COMPILE=1 表示 nvidia 交叉编译。
        L4T_ROS=/l4t/targetfs/opt/ros/humble
        if [ ! -d "$L4T_ROS/share" ]; then
            echo "ERROR: $L4T_ROS 不存在。请确认 Jetson targetfs 已部署。" >&2
            exit 1
        fi
        if [ -f "$L4T_ROS/setup.bash" ]; then
            source "$L4T_ROS/setup.bash"
        fi
        export AMENT_PREFIX_PATH="$(echo "$L4T_ROS:$AMENT_PREFIX_PATH" | tr ':' '\n' | grep -v '^/opt/ros/humble$' | grep -v '^$' | paste -sd ':')"
        export CMAKE_PREFIX_PATH="$(echo "$L4T_ROS:$CMAKE_PREFIX_PATH" | tr ':' '\n' | grep -v '^/opt/ros/humble$' | grep -v '^$' | paste -sd ':')"
        EXTRA_OPTIONS=" -DCMAKE_TOOLCHAIN_FILE=/l4t/Toolchain_aarch64_l4t.cmake"
    fi

    cmake ${EXTRA_OPTIONS} \
          -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/build_dist/common ..

    build_make
}

function main() {
    local cmd=$1
    cd ${WS}
    if [ -z $1 ]; then
        if [ ! -d "build" ]; then
            cmd=all
        else
            cmd=build
        fi
    fi

    START_TIME=$(get_now)

    case $cmd in
        build)
            build_make
            ;;
        all)
            build
            ;;
        clean)
            clean
            ;;
        *)
            echo "Usage: ./build.sh [build|all|clean]"
            exit 1
            ;;
    esac
}

main $@
