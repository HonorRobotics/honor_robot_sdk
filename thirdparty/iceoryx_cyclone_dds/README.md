# iceoryx_cyclone_dds

基于 iceoryx（共享内存，单机）与 CycloneDDS（网络，多机）的 ROS2 中间件。

- **单机内**：进程间通过 iceoryx 共享内存通信，零拷贝、低延迟（需 RouDi 常驻）。
- **跨机器**：通过 CycloneDDS（DDS 网络，UDP 多播/单播）通信。

`install_aarch64/` 与 `install_x86_64/` 目录内为对应平台的已编译产物，部署时整体拷贝即可；`setup.sh` / `run_roudi.sh` 会按当前平台（`uname -m`）自动选择。

---

## 目录结构

```
iceoryx_cyclone_dds/
├── config/
│   ├── cyclonedds.xml          # CycloneDDS 配置（共享内存开关、网卡名）
│   ├── roudi_config.toml       # RouDi 共享内存配置（16GB+ 大容量默认）
│   ├── roudi_config_1g.toml    # 1GB 内存板
│   ├── roudi_config_2g.toml    # 2GB 内存板
│   ├── roudi_config_4g.toml    # 4GB 内存板（脚本默认）
│   └── roudi_config_8g.toml    # 8GB 内存板
├── install_aarch64/            # aarch64 编译产物（so、iox-roudi、ddsperf 等）
├── install_x86_64/             # x86_64 编译产物（so、iox-roudi、ddsperf 等）
├── setup.sh                    # 环境变量脚本（路径自适应 + 平台自动检测，无需挂 /opt）
├── run_roudi.sh                # 启动 RouDi 守护进程（平台自动检测）
└── README.md
```

---

## 环境要求

| 项目 | 要求 |
|------|------|
| CPU 架构 | **x86_64 与 aarch64 均支持**（脚本按 `uname -m` 自动选择 `install_<arch>`） |
| ROS2 | Humble（默认 `/opt/ros/humble`，可用 `ROS_DISTRO_DIR` 覆盖） |
| 系统 | Linux（RouDi 依赖 POSIX 共享内存 `/dev/shm`） |

---

## 快速开始

### 1. 部署到开发板（任意目录，无需 /opt）

把整个目录拷贝到板子上任意位置，例如：

```bash
rsync -aP \
  ./iceoryx_cyclone_dds \
  board_user@<板子IP>:/home/board_user/iceoryx_cyclone_dds
```

> 脚本路径已改为**基于脚本自身位置自适应**，放到任何目录都能正常 source / 运行；`setup.sh` 与 `run_roudi.sh` 会**按当前平台自动选择** `install_x86_64/` 或 `install_aarch64/`，无需手动指定。

### 2. 配置网络接口（跨机通信必须）

编辑 `config/cyclonedds.xml`，把 `NetworkInterface name="eth0"` 改成板子**连接机器人的那张网卡名**：

```bash
ip -br a          # 查看网卡名
vi config/cyclonedds.xml
```

```xml
<NetworkInterface name="eth0"></NetworkInterface>   <!-- 改成实际网卡，如 enp3s0 / wlan0 / usb0 -->
```

> 板子与机器人主机之间走 DDS 网络，两者的 `ROS_DOMAIN_ID` 必须一致（默认 `0`）。
> 若网络不支持多播，需在 `cyclonedds.xml` 中增加 `<Peers><Peer address="对端IP"/></Peers>` 走单播。

### 3. 选择 RouDi 内存配置

| 开发板内存 | 配置文件 | 共享内存占用 |
|-----------|----------|-------------|
| 1GB | `roudi_config_1g.toml` | ~0.25 GB |
| 2GB | `roudi_config_2g.toml` | ~0.52 GB |
| 4GB | `roudi_config_4g.toml`（默认） | ~1.04 GB |
| 8GB | `roudi_config_8g.toml` | ~1.85 GB |
| 16GB+ | `roudi_config.toml` | ~3.68 GB |

> 共享内存池需能装进 `/dev/shm`，用 `df -h /dev/shm` 确认容量够用；不够可在板子上
> `sudo mount -o remount,size=2G /dev/shm` 临时调大。

### 4. 启动 RouDi 并运行 ROS2 程序

```bash
cd <部署目录>/iceoryx_cyclone_dds

# 终端 1：启动 RouDi（按板子内存选配置，默认 4g）
./run_roudi.sh                     # 等价于 ./run_roudi.sh roudi_config_4g.toml

# 终端 2：加载环境后运行 ROS2 程序
source setup.sh
ros2 run <你的包> <节点>
```

指定配置的两种写法等价：

```bash
./run_roudi.sh roudi_config_2g.toml
ROUDI_CONFIG=roudi_config_2g.toml ./run_roudi.sh
```

### 5. 验证

```bash
source setup.sh
ros2 topic list        # 应能看到板子 + 机器人主机两边的 topic
ros2 node list
ros2 doctor            # 确认 RMW 加载为 CycloneDDS
```

---

## 环境变量说明

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `RMW_IMPLEMENTATION` | `rmw_cyclonedds_cpp` | 使用的 RMW 层 |
| `ROS_DISTRO_DIR` | `/opt/ros/humble` | ROS2 安装目录（setup.sh 内读取，可覆盖） |
| `ROS_DOMAIN_ID` | `0` | DDS 域 ID，跨机通信时各机器需一致 |
| `CYCLONEDDS_URI` | `<脚本目录>/config/cyclonedds.xml` | CycloneDDS 配置文件 |
| `ROUDI_CONFIG` | `roudi_config_4g.toml` | run_roudi.sh 使用的内存配置 |
| `ICX_ARCH` | 自动检测（`x86_64`/`aarch64`） | setup.sh 检测并导出的平台标识 |
| `ICX_INSTALL_DIR` | `<脚本目录>/install_<ICX_ARCH>` | setup.sh 检测并导出的产物目录 |

---

## 常见问题

1. **共享内存不生效 / RouDi 报错**：每个机器必须**单独跑一个 `run_roudi.sh`**，RouDi 是本机守护进程，跨不了机器。
2. **跨机发现不了对端**：检查 `cyclonedds.xml` 网卡名、两端 `ROS_DOMAIN_ID`、防火墙是否放行 UDP 多播。
3. **`/dev/shm` 不够**：换更小的 `roudi_config_*.toml`，或临时 `mount -o remount,size=... /dev/shm`。
4. **架构不匹配**：`iox-roudi`、`.so` 已分别提供 x86_64 与 aarch64 两套，由脚本按 `uname -m` 自动选择；若当前平台无对应 `install_<arch>` 目录，脚本会报错提示。
