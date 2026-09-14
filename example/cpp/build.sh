#!/bin/bash

# Honor Robot SDK - C++ examples build script
# 编译方式与 sensor 仓一致(cmake + make,非 colcon),支持交叉编译。
#
# 根因说明:本机 /opt/ros/humble 可能不完整(缺 spdlog_vendor 等 rclcpp 传递依赖),
# 故 x86 本机独立 cmake 会失败。camera_drivers 能编译是因为走交叉编译——
# /l4t/targetfs 下有完整 ROS humble + spdlog_vendor。本脚本对齐该方式。
#
# Usage(与工程约定一致,通常由顶层 honor_robot_sdk/build.sh 调用,也可单独编译):
#   CROSS_COMPILE=1 ./build.sh all        # nvidia 交叉编译
#   CROSS_COMPILE=rk3588s ./build.sh all  # rockchip 交叉编译
#   ./build.sh all                        # 非交叉编译(x86,需 /opt/ros/humble 完整)
#   ./build.sh clean                      # 清理
# Environment variables:
#   CROSS_COMPILE        # 1(l4t) | rk3588s (留空=x86本机)
#   BUILD_DIST           # 安装根目录(默认 $PWD;整体编译时顶层设为 out/)
#
# 依赖说明:
#   rclcpp 的传递依赖 rcl_logging_spdlog 需要 spdlog 的 cmake config(spdlogConfig.cmake)。
#   若本机 /opt/ros/humble 是 ROS 官方包,通常带 spdlog_vendor 已转发 spdlog,可直接编译。
#   若本机 /opt/ros/humble 残缺(缺 spdlog_vendor),find_package(rclcpp) 会在 spdlog 处失败,
#   此时需补装开发包(任选其一):
#     apt-get install -y libspdlog-dev
#     apt-get install -y ros-humble-spdlog-vendor   # 若 apt 源含 ROS 包
#   装好后无需改脚本,直接 ./build.sh all 即可。
#   BUILD_DIST           # 安装根目录(默认 $PWD)
#
# 前置:若示例依赖 common/ 消息包,需先构建 common 并 source 其 setup.bash。
#      camera_echo 只依赖 rclcpp + sensor_msgs,无需 common 即可单独编译。
#      camera_status_echo 依赖 sys_monitor_msgs(common/ 消息包),需先构建 common。

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
        success 'Build passed! Examples compiled successfully.'
        # 补顶层 setup.bash:链式 source common overlay + 本 prefix 示例包。
        # examples 依赖 common 的消息库(libsys_monitor_msgs 等),故先 source common。
        cat > "${INSTALL_DIR}/build_dist/examples/setup.bash" <<'EOF'
#!/usr/bin/env bash
# 由 example/cpp/build.sh 生成。source common overlay + 本 prefix 示例包。
# examples 依赖 common 的消息库,故先 source common/setup.bash(它已含基础 ROS)。
# common/setup.bash 已把 common prefix 加入 CMAKE_PREFIX_PATH,此处再把 examples
# prefix 也加入(运行时 ros2 按包名定位可执行需要 AMENT_PREFIX_PATH,已由 local_setup 处理)。
# 变量均加 _EX_ 前缀,避免与 common/setup.bash(本文件会 source 它)的同名变量互相 clobber。

_EX_PREFIX="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1) common overlay(自动 source 基础 ROS + common 全部消息包 + CMAKE_PREFIX_PATH)
_EX_COMMON_SETUP="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/setup.bash"
if [ -f "$_EX_COMMON_SETUP" ]; then
    source "$_EX_COMMON_SETUP"
else
    echo "[examples/setup.bash] common setup.bash not found at $_EX_COMMON_SETUP (fallback base ROS)" >&2
    [ -f /opt/ros/humble/setup.bash ] && source /opt/ros/humble/setup.bash
fi

# 2) 本 prefix 加入 CMAKE_PREFIX_PATH
case ":${CMAKE_PREFIX_PATH}:" in
    *:"$_EX_PREFIX":*) ;;
    *) export CMAKE_PREFIX_PATH="${_EX_PREFIX}${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}" ;;
esac

# 3) 本 prefix 下所有 ament 包的 local_setup.bash(把 examples 前缀加入 AMENT_PREFIX_PATH,
#    ros2 run 据此定位 honor_robot_sdk_examples 可执行)
for _EX_PKG in "$_EX_PREFIX"/share/*/local_setup.bash; do
    [ -f "$_EX_PKG" ] && source "$_EX_PKG"
done
unset _EX_PKG _EX_COMMON_SETUP _EX_PREFIX
EOF
        info "Run 'source ${INSTALL_DIR}/build_dist/examples/setup.bash' to use the examples."
        info "Then: ros2 run honor_robot_sdk_examples camera_echo"
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

    # 与 sensor/build.sh 一致的 ROS 环境加载 + 交叉编译分支
    ROS_SETUP_PATH="/opt/ros/humble/setup.bash"
    if [ -z "$CROSS_COMPILE" ]; then
        # build for X86(需本机 /opt/ros/humble 完整,含 spdlog_vendor)
        source $ROS_SETUP_PATH

        # 若依赖 common 消息包,source common 的 overlay(可选)
        COMMON_SETUP="${WS}/../../common/build_dist/common/setup.bash"
        [ -v BUILD_DIST ] && COMMON_SETUP="$BUILD_DIST/build_dist/common/setup.bash"
        if [ -f "$COMMON_SETUP" ]; then
            source "$COMMON_SETUP"
            info "Sourced common overlay: $COMMON_SETUP"
        else
            info "(common overlay not found; camera_echo builds fine without it)"
        fi
    elif [ "$CROSS_COMPILE" = "rk3588s" ]; then
        # build for Rockchip rk3588s
        source /rk3588s/sysroot/$SDK_PATH$ROS_SETUP_PATH
        EXTRA_OPTIONS=" -DCMAKE_TOOLCHAIN_FILE=/rk3588s/Toolchain_aarch64_rk3588s.cmake"
        # source common 产物(若整体编译时 BUILD_DIST 已指向 out/)
        COMMON_SETUP="${WS}/../../common/build_dist/common/setup.bash"
        [ -v BUILD_DIST ] && COMMON_SETUP="$BUILD_DIST/build_dist/common/setup.bash"
        if [ -f "$COMMON_SETUP" ]; then
            source "$COMMON_SETUP"
            info "Sourced common overlay: $COMMON_SETUP"
        fi
    elif [ "$CROSS_COMPILE" = "l4t" ] || [ "$CROSS_COMPILE" = "1" ]; then
        # nvidia Jetson (l4t): /l4t/targetfs 下有完整 ROS + spdlog_vendor
        # 注意:本机 /opt/ros/humble 可能残缺(缺 spdlog_vendor)。若交互式 shell 已
        # source 过它,残缺路径会留在 AMENT_PREFIX_PATH 里被优先命中导致 spdlog 找不到。
        # 因此这里显式把 ROS 前缀指向 /l4t/targetfs 并剔除残缺的 /opt/ros/humble。
        # 工程约定 CROSS_COMPILE=1 表示 nvidia 交叉编译。
        L4T_ROS=/l4t/targetfs/opt/ros/humble
        if [ ! -d "$L4T_ROS/share" ]; then
            fail "$L4T_ROS 不存在或无 share/。请确认 Jetson targetfs 已部署,或改用 rk3588s。"
            exit 1
        fi
        # 优先 source l4t 的 setup.bash(若存在,会正确设置 PYTHONPATH 等)
        if [ -f "$L4T_ROS/setup.bash" ]; then
            source "$L4T_ROS/setup.bash"
        fi
        # 无论如何,显式把 l4t 置顶,并从 AMENT_PREFIX_PATH 中剔除残缺的 /opt/ros/humble
        export AMENT_PREFIX_PATH="$(echo "$L4T_ROS:$AMENT_PREFIX_PATH" | tr ':' '\n' | grep -v '^/opt/ros/humble$' | grep -v '^$' | paste -sd ':')"
        export CMAKE_PREFIX_PATH="$(echo "$L4T_ROS:$CMAKE_PREFIX_PATH" | tr ':' '\n' | grep -v '^/opt/ros/humble$' | grep -v '^$' | paste -sd ':')"
        info "l4t cross-compile: AMENT_PREFIX_PATH=$AMENT_PREFIX_PATH"
        EXTRA_OPTIONS=" -DCMAKE_TOOLCHAIN_FILE=/l4t/Toolchain_aarch64_l4t.cmake"
        # source common 产物(整体编译时 BUILD_DIST=out/,common 已装到 out/build_dist/common/)
        COMMON_SETUP="${WS}/../../common/build_dist/common/setup.bash"
        [ -v BUILD_DIST ] && COMMON_SETUP="$BUILD_DIST/build_dist/common/setup.bash"
        if [ -f "$COMMON_SETUP" ]; then
            source "$COMMON_SETUP"
            info "Sourced common overlay: $COMMON_SETUP"
        fi
    else
        fail "Unknown CROSS_COMPILE='$CROSS_COMPILE'. Use: 1(l4t) | rk3588s | (empty for x86)"
        exit 1
    fi

    cmake ${EXTRA_OPTIONS} \
          -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/build_dist/examples ..

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
            echo "Usage: ./build.sh [build|all|clean]  (set CROSS_COMPILE=l4t|rk3588s for cross-compile)"
            exit 1
            ;;
    esac
}

main $@
