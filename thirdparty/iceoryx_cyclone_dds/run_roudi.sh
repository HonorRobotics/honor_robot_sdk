#!/usr/bin/env bash
# 启动 RouDi（iceoryx 共享内存守护进程）
# 路径基于本脚本自身位置推导；按平台选择 install_<arch>；可用 ROUDI_CONFIG 指定内存配置。
# 用法：./run_roudi.sh [roudi_config.toml]

ICX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载环境（含平台检测，导出 ICX_INSTALL_DIR）
source "${ICX_DIR}/setup.sh" || { echo "错误：加载 setup.sh 失败" >&2; exit 1; }

# 默认使用 4G 内存配置；可通过命令行参数或 ROUDI_CONFIG 环境变量覆盖
ROUDI_CONFIG="${1:-${ROUDI_CONFIG:-roudi_config_4g.toml}}"
CONFIG_PATH="${ICX_DIR}/config/${ROUDI_CONFIG}"

if [ ! -f "${CONFIG_PATH}" ]; then
    echo "错误：找不到 RouDi 配置 ${CONFIG_PATH}" >&2
    echo "可选配置：$(ls "${ICX_DIR}"/config/roudi_config*.toml 2>/dev/null | xargs -n1 basename | tr '\n' ' ')" >&2
    exit 1
fi

echo "使用 RouDi 配置：${ROUDI_CONFIG}"
"${ICX_INSTALL_DIR}/iceoryx_posh/bin/iox-roudi" --config "${CONFIG_PATH}"
