#!/bin/bash

# Honor Robot SDK 整体编译脚本
# 参考 sdk/scripts/build/build_all.sh 的编排模式:
#   1. 统一设置 ROS 环境 + 交叉编译分支
#   2. 统一输出目录 out/ (BUILD_DIST)
#   3. 串行编译: common(消息包) → example(C++ 示例)
#      example 自动 source common 的 install/local_setup.bash,以找到消息包
#
# 用法(与工程约定一致):
#   CROSS_COMPILE=1 ./build.sh all        # nvidia 交叉编译
#   CROSS_COMPILE=rk3588s ./build.sh all  # rockchip 交叉编译
#   ./build.sh all                        # 非交叉编译(x86)
#   ./build.sh clean                      # 清理 out/ 及各子模块 build 产物
#
# 说明:common 和 example 各自的 build.sh 也支持单独编译,本脚本只是把两者
#      按依赖顺序串起来并统一输出目录。

BASE_DIR=$(cd $(dirname $0);pwd)
DIST_DIR="$BASE_DIR/out"

# 统一输出目录与离线开关(透传给子模块 build.sh)
export BUILD_DIST="$DIST_DIR"
export BUILD_OFFLINE=1

BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[32m'
WHITE='\033[34m'
YELLOW='\033[33m'
NO_COLOR='\033[0m'

function info()    { (>&2 echo -e "[${WHITE}${BOLD} INFO ${NO_COLOR}] $*"); }
function error()   { (>&2 echo -e "[${RED} ERROR ${NO_COLOR}] $*"); }
function warning() { (>&2 echo -e "[${YELLOW} WARNING ${NO_COLOR}] $*"); }
function ok()      { (>&2 echo -e "[${GREEN}${BOLD} OK ${NO_COLOR}] $*"); }
function print_delim() { echo '=================================================='; }
function get_now() { echo $(date +%s); }
function print_time() {
    END_TIME=$(get_now)
    info "Took $(echo "$END_TIME - $START_TIME" | bc -l) seconds"
}
function success() { print_delim; ok "$1"; print_time; print_delim; }
function fail()    { print_delim; error "$1"; print_time; print_delim; }

# ---------------- SDK 版本(唯一来源:根目录 VERSION 文件) ----------------
SDK_VERSION="$(cat "$BASE_DIR/VERSION" 2>/dev/null | tr -d '[:space:]')"
if [ -z "$SDK_VERSION" ]; then
    SDK_VERSION="unknown"
    warning "VERSION file not found at $BASE_DIR/VERSION, SDK_VERSION=unknown"
fi

# ---------------- 解析 CROSS_COMPILE ----------------
# 工程约定调用方式(与 sdk/scripts/build/build_all.sh 一致):
#   CROSS_COMPILE=1 ./build.sh all        # nvidia 交叉编译
#   CROSS_COMPILE=rk3588s ./build.sh all  # rockchip 交叉编译
#   ./build.sh all                        # 非交叉编译(x86)
# 既支持环境变量前置(CROSS_COMPILE=1 ./build.sh),也支持参数形式(./build.sh CROSS_COMPILE=1)。
# CROSS_COMPILE=1 / l4t 均映射为 nvidia Jetson 交叉编译。
for arg in "$@"; do
    case "$arg" in
        CROSS_COMPILE=1|CROSS_COMPILE=l4t) export CROSS_COMPILE=l4t; break ;;
        CROSS_COMPILE=rk3588s)             export CROSS_COMPILE=rk3588s; break ;;
        CROSS_COMPILE=aarch64-poky-linux-) export CROSS_COMPILE=aarch64-poky-linux-; break ;;
    esac
done

# ---------------- 统一 ROS 环境(与 build_all.sh 一致) ----------------
ROS_SETUP_PATH="/opt/ros/humble/setup.bash"
if [ -z "$CROSS_COMPILE" ]; then
    # 非交叉编译(x86)
    source $ROS_SETUP_PATH
elif [ "$CROSS_COMPILE" = "aarch64-poky-linux-" ]; then
    source /opt/poky/5.0.12/environment-setup-cortexa76-cortexa55-poky-linux
    source /opt/poky/5.0.12/sysroots/cortexa76-cortexa55-poky-linux/$ROS_SETUP_PATH
elif [ "$CROSS_COMPILE" = "rk3588s" ]; then
    source /rk3588s/sysroot/$SDK_PATH$ROS_SETUP_PATH
elif [ "$CROSS_COMPILE" = "l4t" ]; then
    # nvidia Jetson (l4t): 显式指向 /l4t/targetfs 并剔除残缺的 /opt/ros/humble
    # (与 common/build.sh、example/cpp/build.sh 一致)
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
fi

if [ -z "$CROSS_COMPILE" ]; then arch="x86_64"; else arch="$CROSS_COMPILE"; fi

# ---------------- 单模块编译封装 ----------------
build_module() {
    local module_name=$1
    local module_dir=$2

    echo ""
    print_delim
    echo "Building $module_name"
    print_delim

    if [ ! -d "$module_dir" ]; then
        error "directory not found: $module_dir"
        return 1
    fi
    if [ ! -f "$module_dir/build.sh" ]; then
        error "find no build.sh for $module_name at $module_dir"
        return 1
    fi

    cd "$module_dir" || { error "cd $module_dir failed"; return 1; }
    if bash ./build.sh all; then
        ok "Build Success: $module_name"
        return 0
    else
        error "Build Error: $module_name"
        return 1
    fi
}

# ---------------- main ----------------
START_TIME=$(get_now)
cd "$BASE_DIR" || exit 1

# 扫描参数,识别 clean(支持 CROSS_COMPILE=1 ./build.sh clean / ./build.sh clean 两种形式)
CMD=""
for arg in "$@"; do
    case "$arg" in
        clean) CMD="clean" ;;
        all)   CMD="all" ;;
    esac
done

# clean: 清理统一输出目录 + 各子模块本地 build 产物
if [[ "$CMD" == "clean" ]]; then
    info "cleaning out/ and module build artifacts..."
    rm -rf "$DIST_DIR"
    rm -rf "$BASE_DIR/common/build" "$BASE_DIR/common/build_dist"
    rm -rf "$BASE_DIR/example/cpp/build" "$BASE_DIR/example/cpp/build_dist"
    ok "clean done."
    exit 0
fi

# 初始化输出目录
if [ -d "$DIST_DIR" ]; then
    info "clean up directory $DIST_DIR..."
    rm -rf "${DIST_DIR:?}/"*
else
    info "create directory $DIST_DIR..."
    mkdir -p "$DIST_DIR"
fi

# 版本随构建产物一起输出,便于部署侧溯源
echo "$SDK_VERSION" > "$DIST_DIR/VERSION"

# 打包中间件(iceoryx + CycloneDDS)到 out/,便于整体 scp 部署。
# 双架构预编译产物 + 路径自适应脚本,setup.sh 按 uname -m 自动选架构;
# 机器人大脑已自带中间件无需运行这里的 RouDi,笔记本/外挂算力调试时用。
MIDDLEWARE_DIR="$BASE_DIR/thirdparty/iceoryx_cyclone_dds"
if [ -d "$MIDDLEWARE_DIR" ]; then
    cp -a "$MIDDLEWARE_DIR" "$DIST_DIR/"
    info "packaged middleware: $DIST_DIR/iceoryx_cyclone_dds"
else
    warning "middleware not found at $MIDDLEWARE_DIR, skip packaging"
fi

echo "============== Honor Robot SDK v$SDK_VERSION | platform: $arch ================="
info "BASE_DIR=$BASE_DIR"
info "DIST_DIR=$DIST_DIR"

# 阶段 1: 编译 common(消息包)
if ! build_module "common" "$BASE_DIR/common"; then
    fail "common build failed. Terminating."
    exit 2
fi

# source common 产物,让 example 能找到 interaction_msgs / robot_msgs
COMMON_SETUP="$DIST_DIR/build_dist/common/setup.bash"
if [ -f "$COMMON_SETUP" ]; then
    source "$COMMON_SETUP"
    info "Sourced common overlay: $COMMON_SETUP"
else
    warning "common setup.bash not found at $COMMON_SETUP (camera_echo 不依赖消息包,可继续)"
fi

# 阶段 2: 编译 example(C++ 示例)
if ! build_module "example" "$BASE_DIR/example/cpp"; then
    fail "example(C++) build failed. Terminating."
    exit 2
fi

# 注:Python 示例(example/python/*.py)是纯脚本,无需编译,直接运行。
# 打包到 build_dist/examples/python/ 下,与 C++ 的 build_dist/examples/lib/ 并列,
# 统一由 examples/setup.bash 覆盖(该文件已 source common,含 Python 消息绑定)。
mkdir -p "$DIST_DIR/build_dist/examples/python/common" "$DIST_DIR/build_dist/examples/python/product"
for pydir in common product; do
    if compgen -G "$BASE_DIR/example/python/$pydir/*.py" > /dev/null; then
        cp "$BASE_DIR/example/python/$pydir/"*.py "$DIST_DIR/build_dist/examples/python/$pydir/"
    fi
done
info "packaged python examples: $DIST_DIR/build_dist/examples/python"

success "Honor Robot SDK build completed."
info "SDK version:   $SDK_VERSION"
info "common:        $DIST_DIR/build_dist/common/setup.bash"
info "example(C++):  $DIST_DIR/build_dist/examples/setup.bash"
# 运行指引:自动扫描已安装示例(C++ 可执行 + Python 脚本),逐个打印运行命令。
# 与 CMake file(GLOB) 自动扫描一致 —— 新增示例无需改本脚本。
info "---- 运行示例 ----"
# C++ 可执行装在 install 前缀(CMAKE_INSTALL_PREFIX=build_dist/examples)下的
# lib/honor_robot_sdk_examples/,注意路径中无 install/ 子目录。
EXE_DIR="$DIST_DIR/build_dist/examples/lib/honor_robot_sdk_examples"
if [ -d "$EXE_DIR" ]; then
    for exe in "$EXE_DIR"/*; do
        [ -f "$exe" ] || continue
        info "run C++:  source $DIST_DIR/build_dist/examples/setup.bash && ros2 run honor_robot_sdk_examples $(basename "$exe")"
    done
fi
for py in "$BASE_DIR"/example/python/common/*.py "$BASE_DIR"/example/python/product/*.py; do
    [ -f "$py" ] || continue
    # 与 C++ 示例同一 setup.bash(examples/setup.bash 已 source common),lib 与 python 并列
    rel="${py#*example/python/}"
    info "run Py:   source $DIST_DIR/build_dist/examples/setup.bash && python3 $DIST_DIR/build_dist/examples/python/$rel"
done
exit 0
