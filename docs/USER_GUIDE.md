# 用户使用指南 — 部署到机器人大脑并运行

> 面向二开开发者：从拿到 SDK 源码,到在**机器人大脑**(aarch64,Ubuntu 22.04 + ROS2 Humble)上构建、部署、运行示例程序的完整步骤。
>
> 本 SDK **不做额外 API 封装层**,用户直接用 ROS2 topic/service/action 与机器人通信。本指南只讲"怎么把它跑起来",接口含义见 [`../README.md`](../README.md)。

---

## 0. 前置条件

### 0.1 机器人大脑环境

机器人大脑是一台运行 **Ubuntu 22.04 + ROS2 Humble** 的 **aarch64 (ARM64)** 设备(Jetson / Rockchip 平台)。确认以下条件:

| 条目 | 要求 | 验证命令 |
|------|------|---------|
| ROS2 | Humble,`/opt/ros/humble/setup.bash` 可用 | `ls /opt/ros/humble/setup.bash` |
| 架构 | aarch64 (机器人本体) 或 x86_64 (开发机) | `uname -m` |
| 编译工具 | cmake ≥ 3.12、g++、make | `cmake --version` |
| Python | python3 ≥ 3.10(机器人本体为 3.10.12) | `python3 --version` |
| 网络 | 开发机与机器人大脑可互通(ssh/scp) | `ssh <brain_ip>` |

> 机器人大脑上的 ROS2 节点(传感器、控制器等)需已正常启动并发布话题——本 SDK 的示例是"订阅/控制"侧程序,依赖机器人端先跑起来。

### 0.2 两种部署路径

| 路径 | 适用场景 | 说明 |
|------|---------|------|
| **A. 本机直接构建** | 机器人大脑上有完整编译环境 | 在大脑上 clone + `./build.sh all`,直接产出可运行程序。最简单。 |
| **B. 交叉编译 + 拷贝部署** | 大脑算力/环境受限,开发机上编译 | 开发机(x86)用 `CROSS_COMPILE` 交叉编译出 aarch64 产物,再把 `out/` 拷到大脑。推荐。 |

> **`lib/` 预编译包暂不提供**(为空占位),因此无论哪条路径都需要**从源码构建 `common/` 消息包**。

---

## 1. 获取 SDK 源码

```bash
git clone <sdk_repo_url> honor_robot_sdk
cd honor_robot_sdk
```

目录结构与各部分作用见 [`../README.md`](../README.md)。本指南涉及的关键文件:

```
honor_robot_sdk/
├── build.sh                  # 顶层编译(common→example 串行,输出 out/)
├── common/                   # ROS2 消息包(必须先构建,供示例/你的程序依赖)
├── common.sync.yaml          # 同步配置(开发者维护接口清单用,运行时无关)
├── example/cpp/              # C++ 示例(camera_echo / camera_status_echo 等)
└── example/python/           # Python 示例(纯脚本,无需编译)
```

---

## 2. 构建

### 2.1 路径 A:在机器人大脑上直接构建

大脑上已具备 ROS2 Humble + cmake/g++,直接编译:

```bash
cd honor_robot_sdk

# 加载 ROS2 环境(若 shell 未自动加载)
source /opt/ros/humble/setup.bash

# 编译(串行:common 消息包 → example C++ 示例,统一输出到 out/)
./build.sh all
```

### 2.2 路径 B:开发机交叉编译

开发机需安装对应交叉编译工具链。按大脑平台选择 `CROSS_COMPILE`:

| 平台 | 交叉编译命令 | 工具链/sysroot 要求 |
|------|-------------|-------------------|
| Jetson (l4t) | `CROSS_COMPILE=1 ./build.sh all` | `/l4t/targetfs/opt/ros/humble` 完整部署 |
| Rockchip (rk3588s) | `CROSS_COMPILE=rk3588s ./build.sh all` | `/rk3588s/sysroot` + `Toolchain_aarch64_rk3588s.cmake` |
| Rockchip (poky) | `CROSS_COMPILE=aarch64-poky-linux- ./build.sh all` | `/opt/poky/5.0.12/` 环境 |

```bash
cd honor_robot_sdk

# 示例:为 Jetson 大脑交叉编译
CROSS_COMPILE=1 ./build.sh all
```

> 交叉编译分支与内部仓 `build_all.sh` 完全一致:`CROSS_COMPILE=1`/`l4t` 均映射为 nvidia Jetson。脚本会自动 source 对应平台的 ROS sysroot 并剔除残缺的本机 `/opt/ros/humble`。

### 2.3 构建产物

无论哪条路径,产物都落在 `out/` 下:构建产物在 `build_dist/`(消息包 + C++ 示例),另含双架构预编译中间件 `iceoryx_cyclone_dds/`(外接笔记本/算力板调试用,见下文[第 5 节](#5-外接-ubuntu-笔记本--算力板调试)):

```
out/build_dist/
├── common/                      # ★ 消息包产物(interaction_msgs/robot_msgs/camera_msgs/sys_monitor_msgs)
│   ├── setup.bash               #   ★ 顶层 overlay(source 它即拿到全部消息包 + 基础 ROS)
│   ├── lib/                     #   .so 库(C++ 链接用)
│   ├── local/lib/python3.x/...  #   Python 绑定(import 用)
│   └── share/<pkg>/             #   per-package local_setup.bash + cmake config
└── examples/                    # ★ C++ 示例产物(honor_robot_sdk_examples)
    ├── setup.bash               #   ★ 顶层 overlay(链式 source common,source 它即全搞定)
    └── lib/honor_robot_sdk_examples/   #   可执行文件(camera_echo / camera_status_echo / ...)
```

- **`common/setup.bash`** —— 消息包产物。你的程序若用到 `interaction_msgs`/`robot_msgs` 等消息,**必须先 source 它**。
- **`examples/setup.bash`** —— C++ 示例的安装产物,`source` 后即可用 `ros2 run honor_robot_sdk_examples <示例名>` 运行(它会自动带上 common,故无需再单独 source common)。
- **`out/iceoryx_cyclone_dds/`** —— 双架构预编译中间件(iceoryx + CycloneDDS),`build.sh` 自动打包,供笔记本/算力板跨机调试部署,见[第 5 节](#5-外接-ubuntu-笔记本--算力板调试)。
- Python 示例是纯脚本,**无需编译**,但若依赖消息包仍需 `source` common 产物。

> **source 顺序**:先 `source` ROS2 基础环境,再 `source` SDK 的 `setup.bash`(顺序不能反)。`examples/setup.bash` 会自动带上 common,source 一个即可同时拿到消息包与示例可执行。

### 2.4 单独编译某一模块

也可不经过顶层 `build.sh`,单独编译消息包或示例(参数一致):

```bash
cd common       && ./build.sh all    # 仅编译消息包
cd example/cpp  && ./build.sh all    # 仅编译 C++ 示例(若依赖消息包需先 source common 产物)
```

### 2.5 清理

```bash
./build.sh clean    # 清理 out/ 及各子模块 build 产物
```

### 2.6 验证编译成功

```bash
# 消息包应生成 .so 与 Python 绑定
ls out/build_dist/common/lib/ | grep -E "interaction_msgs|robot_msgs"

# 示例可执行文件应存在
ls out/build_dist/examples/lib/honor_robot_sdk_examples/
# 期望看到: camera_echo、camera_status_echo 等
```

---

## 3. 部署到机器人大脑

### 3.1 路径 A:本机构建,无需拷贝

已在机器人大脑上构建的,跳过本节,直接到 [第 4 节:运行](#4-运行)。

### 3.2 路径 B:把交叉编译产物拷到大脑

开发机交叉编译完成后,把整个 `out/` 拷到机器人大脑。两种方式任选:

**方式一:rsync 直接拷贝(推荐)**——保留符号链接、支持断点/增量,要求**两端都装 rsync**:

```bash
# 在开发机上(把 <brain_ip> 换成大脑地址,<brain_user> 换成登录用户)
# 用 rsync -aP 而非 scp -r:out/ 里含中间件 iceoryx_cyclone_dds/ 的 .so 符号链接,
# scp -r 默认跟随链接、会拷坏链接结构
rsync -aP out/ <brain_user>@<brain_ip>:~/honor_robot_sdk_out/
```

**方式二:压缩包拷贝**——目标机只要有 ssh/tar 即可(无需 rsync);tar 默认保留符号链接,`out/` 里中间件的 `.so` 链接解压后完好:

```bash
# 开发机上:打包 out/(build_dist + 中间件 + VERSION)
tar -C out -czf honor_robot_sdk_out.tar.gz .

# 传到大脑(scp 单个文件,不受符号链接问题影响)
scp honor_robot_sdk_out.tar.gz <brain_user>@<brain_ip>:~/

# 大脑上解压到目标目录
ssh <brain_user>@<brain_ip> 'mkdir -p ~/honor_robot_sdk_out && tar -C ~/honor_robot_sdk_out -xzf ~/honor_robot_sdk_out.tar.gz'
```

> **符号链接怎么保住**:`rsync -aP` 和 `tar` 都默认保留符号链接(打包时**不要**加 `-h`/`--dereference`,那会把 `.so` 链接展开成目标文件);只有 `scp -r` 会跟随链接、拷坏链接结构。
> 机器人大脑**用不到** `out/` 里的中间件(本体已自带),拷完整无副作用;若目标机既没 rsync 也嫌麻烦退化用 `scp -r out/`,中间件链接会被展开但大脑不依赖它,不影响运行。**注意**:被 `scp` 展开过的 `iceoryx_cyclone_dds/` **不要**转拷给笔记本/算力板——外部设备按[第 5 节](#5-外接-ubuntu-笔记本--算力板调试)用 rsync 或压缩包方式。

> 只想拷消息包 + 示例(更轻量,跳过中间件):`scp -r out/build_dist/common`、`scp -r out/build_dist/examples` 即可(build_dist 无符号链接,scp 安全),或 `tar -C out/build_dist -czf common_examples.tar.gz .`。

> 若你用 Python 示例且大脑上有完整源码,也可只拷 `common` 产物 + `example/python/` 脚本,跳过 C++ 编译产物。

### 3.3 在机器人大脑上准备运行环境

```bash
ssh <brain_user>@<brain_ip>

# 1) 加载大脑上的 ROS2 环境
source /opt/ros/humble/setup.bash

# 2) 加载 SDK 消息包 overlay(本机构建用 out/,拷贝部署用你拷过去的目录)
source ~/honor_robot_sdk_out/build_dist/common/setup.bash

# 3)(可选)加载 C++ 示例 overlay
source ~/honor_robot_sdk_out/build_dist/examples/setup.bash
```

> **顺序很重要**:先 `source` ROS2 基础环境,再 `source` SDK 的 overlay。SDK 消息包是在 ROS2 之上的扩展,后者依赖前者。

---

## 4. 运行

### 4.1 确认机器人端话题就绪

运行 SDK 程序前,先确认机器人大脑上的 ROS2 节点已发布对应话题:

```bash
# 查看所有话题
ros2 topic list

# 确认相机话题存在(以 camera_echo 为例)
ros2 topic list | grep pelvis_rgbd_color_image
# 期望看到: sensor/pelvis_rgbd_color_image

# 确认有数据在发(看一帧)
ros2 topic echo sensor/pelvis_rgbd_color_image --once
```

若话题不存在或无数据,说明机器人端传感器节点未启动,需先启动机器人端服务(联系机器人运维或参考机器人本体文档)。

### 4.2 运行 C++ 示例:`camera_echo`

`camera_echo` 订阅髋部 RGBD 彩色图像,打印元数据(编码/分辨率/FPS),可选保存首帧为 PNG。它只依赖 `rclcpp` + `sensor_msgs`(不依赖本 SDK 消息包),但仍需 `source` 示例 overlay 以找到可执行文件。

```bash
# 前置:已 source ROS2 环境 + 示例 overlay
source /opt/ros/humble/setup.bash
source ~/honor_robot_sdk_out/build_dist/examples/setup.bash

# 运行(默认订阅 sensor/pelvis_rgbd_color_image)
ros2 run honor_robot_sdk_examples camera_echo

# 保存首帧为 PNG(需编译时带 OpenCV/cv_bridge)
ros2 run honor_robot_sdk_examples camera_echo \
  --ros-args -p save_path:=/tmp/frame.png

# 订阅其它相机话题
ros2 run honor_robot_sdk_examples camera_echo \
  --ros-args -p image_topic:=sensor/pelvis_rgbd_color_image
```

正常输出形如:
```
[INFO] 📸 CameraEcho subscribed: sensor/pelvis_rgbd_color_image
[INFO] 📸 Image received
  • frame_id:        ...
  • encoding:        rgb8
  • size (WxH):      1920 x 1080
  • recv FPS (1s):   30.0
```

### 4.3 运行 Python 示例:`camera_echo.py`

Python 示例是纯脚本,无需编译(也不用 `ros2 run`),直接 `python3` 运行:

```bash
# 前置:已 source ROS2 环境(若脚本用到本 SDK 消息包,再 source common overlay)
source /opt/ros/humble/setup.bash
# camera_echo.py 只用 sensor_msgs,无需 common overlay

python3 example/python/common/camera_echo.py

# 保存首帧为 PNG(需安装 cv2/cv_bridge)
python3 example/python/common/camera_echo.py \
  --ros-args -p save_path:=/tmp/frame.png

# 订阅其它话题
python3 example/python/common/camera_echo.py \
  --ros-args -p image_topic:=sensor/pelvis_rgbd_color_image
```

> Python 示例与 C++ 示例功能对齐。纯脚本的好处是改完即跑、无需重新编译,适合快速原型验证。

### 4.4 运行相机状态示例:`camera_status_echo`

`camera_status_echo` 订阅相机状态话题,打印 `CameraStatus` 消息的全部字段:RGB/LDP/IR/IMU/CPU 的温度·频率·起流状态(温度字段以 int16 存储,实际温度 = 原值 / 10.0)。它是**第一个直接使用本 SDK 消息包(`sys_monitor_msgs`)的示例**,演示了"如何获取设备状态"。

> 与 `camera_echo` 不同,它依赖 `sys_monitor_msgs`,因此 Python 版运行前必须 `source` common overlay;C++ 版因 `examples/setup.bash` 已链式带上 common,source examples 即可。

```bash
# C++ 示例(已 source examples/setup.bash,自动含 common 消息包)
ros2 run honor_robot_sdk_examples camera_status_echo

# 订阅其它相机的状态话题(如髋部 RGBD)
ros2 run honor_robot_sdk_examples camera_status_echo \
  --ros-args -p status_topic:=/sensor/pelvis_rgbd_camera_status_param

# Python 示例(需先 source common overlay 以拿到 sys_monitor_msgs)
source ~/honor_robot_sdk_out/build_dist/common/setup.bash
python3 example/python/common/camera_status_echo.py
```

正常输出形如:
```
[INFO] 📊 CameraStatusEcho subscribed: /sensor/pelvis_rgbd_camera_status_param
[INFO] 📊 CameraStatus received
  • device_name:   ...
  ---- RGB ----
  • rgb_temperature:       255  (25.5℃)
  • rgb_frequency:         30 Hz
  • rgb_switch_status:     true(起流)
  ...
  ---- CPU ----
  • cpu_temperature:       420  (42.0℃)
```

> 相机驱动每 2000ms 发布一帧状态,故该示例逐帧打印(不限频)。默认 topic 为髋部 RGBD 相机(`/sensor/pelvis_rgbd_camera_status_param`),可用 `status_topic` 参数覆盖为其它相机(如腹部等)。

### 4.5 使用本 SDK 消息包写自己的程序

本 SDK 的核心价值是 `common/` 下的消息包。构建并 `source` 后,你自己的 ROS2 节点即可直接引用:

```python
# Python:发布速度指令(需先 source common overlay)
from interaction_msgs.msg import Move

pub = self.create_publisher(Move, '/honor/locomotion/move', 10)
msg = Move()
msg.vx = 0.5        # m/s,前进
msg.vy = 0.0        # m/s,侧移
msg.omega = 0.3     # degree/s,旋转
msg.duration = 1.0  # s
pub.publish(msg)
```

```cpp
// C++:在你的 ament_cmake 包中(CMakeLists 加 find_package(interaction_msgs) 并 ament_target_dependencies)
#include "interaction_msgs/msg/move.hpp"
auto pub = node->create_publisher<interaction_msgs::msg::Move>("/honor/locomotion/move", 10);
interaction_msgs::msg::Move msg;
msg.vx = 0.5; msg.vy = 0.0; msg.omega = 0.3;
pub->publish(msg);
```

**关键**:只要 `source` 了 `out/build_dist/common/setup.bash`,`interaction_msgs`/`robot_msgs`/`camera_msgs`/`sys_monitor_msgs` 这些包就会进入 `AMENT_PREFIX_PATH`,你的程序(无论 colcon 还是 cmake 构建)都能 `find_package` 到它们。

各消息包的接口清单与字段含义见 [`../README.md`](../README.md#common--公共交互消息与接口)。

---

## 5. 外接 Ubuntu 笔记本 / 算力板调试

> 适用场景:在**外部计算设备**(Ubuntu 笔记本、外挂算力板等)上跑调试/二次开发程序,直接订阅、控制机器人本体的话题,无需登录机器人本体。此时外部设备需部署与机器人本体**同源**的 ROS2 中间件(`iceoryx + CycloneDDS`),经 DDS 网络跨机器通信。

### 5.1 原理

- **机器人本体**:已运行自带的 RouDi(iceoryx 共享内存守护)+ CycloneDDS,话题在本机发布/订阅。
- **外部设备**:部署同一套中间件,各自启动**自己的 RouDi**(共享内存是本机的,跨不了机器),通过 CycloneDDS 的 UDP 多播/单播发现并收发机器人本体的话题。
- **跨机通信前提**:两端 `ROS_DOMAIN_ID` 一致(默认 0);外部设备连机器人的网卡名写进 `config/cyclonedds.xml`。

### 5.2 部署中间件

中间件是**双架构预编译产物**,`./build.sh all` 时已自动打包进 `out/iceoryx_cyclone_dds/`(`install_x86_64/` + `install_aarch64/`)。整体拷贝到外部设备任意目录即可,`setup.sh`/`run_roudi.sh` 按 `uname -m` 自动选架构:

```bash
# 开发机上,把中间件拷到外部设备(用 rsync -aP,保留 .so 符号链接与权限)
rsync -aP out/iceoryx_cyclone_dds/ <dev_user>@<dev_ip>:~/iceoryx_cyclone_dds/
```

> 为什么用 `rsync -aP` 而非 `scp -r`:`install_x86_64/`、`install_aarch64/` 里的 `.so` 是符号链接(`libddsc.so` → `libddsc.so.0` 等),`scp -r` 默认跟随链接、会拷坏链接结构,设备上库可能加载失败;`rsync -aP` 保留符号链接与权限。

> 外部设备没装 rsync 时,用压缩包方式效果一样(tar 默认保留符号链接):
> ```bash
> tar -C out -czf iceoryx_cyclone_dds.tar.gz iceoryx_cyclone_dds
> scp iceoryx_cyclone_dds.tar.gz <dev_user>@<dev_ip>:~/
> ssh <dev_user>@<dev_ip> 'tar -C ~ -xzf iceoryx_cyclone_dds.tar.gz'
> ```

> 机器人本体**无需**部署这份(本体已自带中间件)。若误拷到本体也无害,但**不要**在本体上运行它的 `run_roudi.sh`——会与本体的 RouDi 冲突。

### 5.3 配置跨机通信

```bash
ip -br a        # 查看外部设备网卡名
vi ~/iceoryx_cyclone_dds/config/cyclonedds.xml
```

把 `<NetworkInterface name="eth0"></NetworkInterface>` 改成**实际连接机器人的网卡**(如 `enp3s0` / `usb0` / `wlan0`)。网络不支持多播时,在 `cyclonedds.xml` 加 `<Peers><Peer address="机器人IP"/></Peers>` 走单播。

### 5.4 启动 RouDi 并加载环境

```bash
cd ~/iceoryx_cyclone_dds

# 终端 1:启动 RouDi(按设备内存选配置,默认 4g;1G 板子用 roudi_config_1g.toml)
./run_roudi.sh

# 终端 2:加载中间件环境(RMW 指向 CycloneDDS)
source setup.sh
```

### 5.5 运行调试程序

```bash
# 前置:已 source setup.sh(含 ROS2 基础 + CycloneDDS)
source ~/iceoryx_cyclone_dds/setup.sh

# 确认 RMW 已加载为 CycloneDDS(应为 rmw_cyclonedds_cpp)
ros2 doctor

# 确认能发现机器人本体话题
ros2 topic list | grep pelvis_rgbd_color_image
ros2 topic echo sensor/pelvis_rgbd_color_image --once

# 只订阅 sensor_msgs/std_msgs 的程序(camera_echo.py 等)到此即可运行
python3 example/python/common/camera_echo.py

# 若程序用到本 SDK 消息包(interaction_msgs 等),再把 common 产物拷到外部设备并 source overlay
source ~/honor_robot_sdk_out/build_dist/common/setup.bash
```

### 5.6 外接调试常见问题

| 现象 | 排查 |
|------|------|
| `ros2 topic list` 看不到机器人话题 | ① 两端 `ROS_DOMAIN_ID` 是否一致;② `cyclonedds.xml` 网卡名是否正确;③ 防火墙是否放行 UDP 多播/单播 |
| RouDi 报共享内存不足 | `df -h /dev/shm` 看容量;换更小 `roudi_config_*.toml`,或 `sudo mount -o remount,size=2G /dev/shm` |
| `source setup.sh` 报找不到产物 | 设备架构须为 x86_64/aarch64;确认 `install_<arch>/setup.bash` 存在 |

> 中间件的环境变量、验证方法等完整说明见 `thirdparty/iceoryx_cyclone_dds/README.md`(随部署目录一起拷贝,设备上也能看)。

---

## 6. 常见问题

### Q1: `ros2 run` 提示找不到包 / `find_package(interaction_msgs)` 失败

**原因**:未 `source` 对应的 `setup.bash`,或 `source` 顺序不对。

**解决**:确认按顺序执行:
```bash
source /opt/ros/humble/setup.bash                                    # 1. ROS2 基础
source <sdk>/out/build_dist/common/setup.bash                # 2. 消息包 overlay
source <sdk>/out/build_dist/examples/setup.bash              # 3.(C++ 示例)示例 overlay
```
验证:`echo $AMENT_PREFIX_PATH` 应同时包含 `/opt/ros/humble` 和 SDK 的 install 路径。

### Q2: 交叉编译时 `find_package(rclcpp)` 失败 / 找不到 spdlog

**原因**:本机 `/opt/ros/humble` 残缺(缺 `spdlog_vendor` 等 rclcpp 传递依赖)。交叉编译分支已自动剔除残缺路径并指向平台 sysroot,但若交互式 shell 之前 `source` 过残缺的 `/opt/ros/humble`,会污染 `AMENT_PREFIX_PATH`。

**解决**:在**干净的 shell** 中执行交叉编译(不要先 `source /opt/ros/humble/setup.bash`);或在大脑对应的 sysroot 下补装:
```bash
apt-get install -y libspdlog-dev
# 或(若 apt 源含 ROS 包)
apt-get install -y ros-humble-spdlog-vendor
```

### Q3: 示例运行但收不到任何数据 / FPS 为 0

**原因**:机器人端对应话题未发布(QoS 不匹配也会导致此现象)。

**解决**:
```bash
ros2 topic list | grep <你的话题>          # 话题是否存在
ros2 topic info -v <话题>                  # 查看 publisher/subscriber 与 QoS
ros2 topic echo <话题> --once              # 是否真有数据
```
`camera_echo` 用的是 `SensorDataQoS`(`BEST_EFFORT` + `KEEP_LAST`),若机器人端 publisher 用 `RELIABLE`,需在示例侧调整 QoS 或让机器人端改用 `BEST_EFFORT`。

### Q4: x86 本机构建 `./build.sh all` 失败,但交叉编译能过

**原因**:本机 `/opt/ros/humble` 不完整(同 Q2)。本 SDK 的构建脚本设计上优先走交叉编译路径(与内部仓 `build_all.sh` 一致)。

**解决**:本机开发优先用 `CROSS_COMPILE=1 ./build.sh all`(Jetson sysroot 完整);若必须本机 x86 编译,补全本机 ROS2 依赖。

### Q5: Python 脚本报 `ModuleNotFoundError: interaction_msgs`

**原因**:未 `source` 消息包 overlay,Python 找不到 rosidl 生成的消息包。

**解决**:`source <sdk>/out/build_dist/common/setup.bash`(它会设置 `PYTHONPATH`)。`camera_echo.py` 只用 `sensor_msgs` 不受影响;用到本 SDK 消息包的脚本必须有此步骤。

### Q6: 部署后换了一台大脑/换了固件,程序报消息不兼容

**原因**:SDK 消息包版本与机器人端不一致(上游 `Xproj_Common` 改过 msg 字段)。

**解决**:查看当前同步的上游版本:
```bash
cat common.sync.lock    # 看 source_commit
```
按 `docs/COMMON_SYNC.md` 重新同步消息包并重新构建,使 SDK 与机器人端固件对齐。

---

## 7. 速查:从零到运行的最短路径

> 假设:机器人大脑有完整编译环境,已连 ROS2 网络,相机节点已启动。

```bash
# 1. 拿源码
git clone <sdk_repo_url> honor_robot_sdk && cd honor_robot_sdk

# 2. 构建(大脑本机)
source /opt/ros/humble/setup.bash
./build.sh all

# 3. 加载环境
source out/build_dist/common/setup.bash
source out/build_dist/examples/setup.bash

# 4. 确认话题
ros2 topic list | grep pelvis_rgbd_color_image

# 5. 运行 C++ 示例
ros2 run honor_robot_sdk_examples camera_echo

# 或运行 Python 示例
python3 example/python/common/camera_echo.py

# 也可运行相机状态示例(依赖 sys_monitor_msgs,演示使用本 SDK 消息包)
ros2 run honor_robot_sdk_examples camera_status_echo
```

看到 `📸 Image received ... recv FPS (1s): 30.0` 即成功。
