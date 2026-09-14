# iceoryx_cyclone_dds 双架构支持 设计文档

- 日期：2026-09-07
- 分支：`honor_trunk_xproj`
- 范围：`thirdparty/iceoryx_cyclone_dds/`

## 背景

`thirdparty/iceoryx_cyclone_dds/` 当前只包含 aarch64 平台的预编译中间件产物（`install/` 内的 `.so` 与 `iox-roudi` 均为 ARM64）。用户已在 `~/iceoryx_cyclone_dds_cpptoml-master` 编译出 x86_64 平台版本，产物位于其 `install/` 下。目标：将两套平台产物统一收纳，并让脚本在部署时按平台自动选择对应产物，使中间件在 x86_64 与 aarch64 下都能直接使用。

## 检查结论（x86_64 产物可用）

- 所有 `.so` 与二进制均为 ELF x86-64（`file` 确认）。
- 包结构与 aarch64 版完全一致：`cyclonedds`、`iceoryx_binding_c`、`iceoryx_hoofs`、`iceoryx_posh`、`rmw_cyclonedds_cpp`、`rmw_iceoryx_cpp`。
- 二进制 `iox-roudi`、`ddsperf` 齐全；`libddsc.so → libddsc.so.0 → libddsc.so.0.10.2` 等符号链接完好。
- 冒烟验证：补上 `LD_LIBRARY_PATH`（模拟 source `setup.bash` 后）时，`iox-roudi --help`、`ddsperf` 均正常输出。
- 说明：直接 `ldd` 报的 `libiceoryx_posh.so => not found` 等为正常现象 —— colcon 产物不写 rpath，依赖 source `setup.bash` 设置的 `LD_LIBRARY_PATH` 解析，aarch64 版同样如此。

## 目录结构（迁移后）

```
thirdparty/iceoryx_cyclone_dds/
├── config/                 # 平台无关，统一复用现有 5 个 roudi_config*.toml + cyclonedds.xml
├── install_aarch64/        # 原 install/ 通过 git mv 改名
├── install_x86_64/         # 从 ~/iceoryx_cyclone_dds_cpptoml-master/install 迁入
├── setup.sh                # 平台检测 + 加载环境
├── run_roudi.sh            # 平台检测 + 启动 RouDi
└── README.md               # 更新
```

## 平台检测逻辑

`setup.sh` 与 `run_roudi.sh` 共用：

```bash
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)  ICX_ARCH="x86_64" ;;
  aarch64|arm64) ICX_ARCH="aarch64" ;;
  *) echo "错误：不支持的架构 $ARCH" >&2; return 1 ;;
esac
ICX_INSTALL_DIR="${ICX_DIR}/install_${ICX_ARCH}"
```

## setup.sh 改动

- 检测 `ICX_ARCH` → 计算 `ICX_INSTALL_DIR`，并 `export` 两者供 `run_roudi.sh` 复用。
- 校验 `"${ICX_INSTALL_DIR}/setup.bash"` 存在，不存在则报错退出。
- 其余逻辑不变：source 基础 ROS（默认 `/opt/ros/humble`，可 `ROS_DISTRO_DIR` 覆盖）→ `export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` → source `install_<arch>/setup.bash` → `export CYCLONEDDS_URI` → `export ROS_DOMAIN_ID`。

## run_roudi.sh 改动

- source `setup.sh` 拿到 `ICX_INSTALL_DIR`。
- 改用绝对路径调用：`"${ICX_INSTALL_DIR}/iceoryx_posh/bin/iox-roudi"`（不依赖 PATH，更稳健）。
- 配置选择逻辑不变：默认 `roudi_config_4g.toml`，可传参或 `ROUDI_CONFIG` 覆盖；配置文件不存在时报错列出可选配置。

## config 目录

不动。x86 版自带的 `config/`（仅 1 个 `roudi_config.toml`）是平台无关 TOML，与本中间件现有 5 档配置重复，直接丢弃，统一复用现有 `config/`。

## 迁移动作

1. `git mv install install_aarch64`（保留历史）。
2. `rsync -a`（保留符号链接与权限）`~/iceoryx_cyclone_dds_cpptoml-master/install/` → `install_x86_64/`。
3. 重写 `setup.sh`、`run_roudi.sh`，更新 `README.md`。

## 验证

- 本机（x86_64）：`source setup.sh` → 确认选中 `install_x86_64`、`iox-roudi` 可被定位；`run_roudi.sh` 能定位到 x86 的 `iox-roudi` 二进制且配置校验通过。
- aarch64 路径本机无法实测，检测逻辑对称，靠 code review 覆盖。
- 不实际启动 RouDi（需 `/dev/shm` 权限/独占），验证到“找到正确二进制 + 配置校验通过”为止。
