# Honor Robot SDK

> 荣耀机器人二开 SDK — 面向外部开发者的机器人接口与仿真部署工具包

本 SDK 核心是 `common/` 中的 ROS2 消息包，用户直接用 ROS2 topic/service/action 与机器人通信，**不做额外 API 封装层**。

---

## 版本兼容性与集成指南

> 请按目标设备平台与机器人系统版本选择匹配的 SDK 版本。

📋 **版本更新历史**：[查看完整版本变更日志 →](CHANGELOG.md)

### 版本对应关系

| 目标设备 | SDK 版本 | 说明 |
|---------|---------|------|
| 机器人大脑（aarch64，Jetson / Rockchip，Ubuntu 22.04 + ROS2 Humble） | **v1.0.0**（推荐） | 二开程序运行主体，与机器人本体同源通信 |
| 外接 Ubuntu 笔记本（x86_64） | **v1.0.0**（推荐） | 跨机调试/开发，需部署 `iceoryx_cyclone_dds` 中间件 |
| 外接算力板（aarch64 / x86_64） | **v1.0.0**（推荐） | 同上 |

### 平台兼容性矩阵

| 平台 | 系统/ROS | SDK 版本 | 维护状态 |
|------|---------|---------|---------|
| 机器人大脑 | Ubuntu 22.04 + ROS2 Humble | v1.0.0 | ✅ 最新版本（推荐） |
| 外接笔记本 | Ubuntu + ROS2 Humble | v1.0.0 | ✅ 最新版本 |
| 外接算力板 | Linux + ROS2 Humble | v1.0.0 | ✅ 最新版本 |

> 机器人固件升级后，请确认 SDK 消息包与机器人端固件字段对齐（必要时重新构建），避免消息字段不兼容。

### 集成注意事项

- **版本不匹配**会导致消息字段不兼容（字段增删/类型变化），引发编译失败或运行时异常，请确保 SDK 消息包与机器人端固件对齐。
- **外接笔记本/算力板**需部署与机器人本体**同源**的中间件 `iceoryx_cyclone_dds` 才能跨机通信，详见 [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) 第 5 节。

---

## 目录结构

```
honor_robot_sdk/
│
├── build.sh                              # 顶层编译脚本(common→example 串行,统一输出 out/)
├── VERSION                               #   SDK 版本号(build.sh 构建时读取并输出到 out/)
│
├── common/                               # ★ 公共交互消息与接口(ROS2 消息包)
│   ├── CMakeLists.txt                    #   顶层 cmake(add_subdirectory)
│   ├── build.sh                          #   cmake+make(与机器人端一致,支持交叉编译)
│   ├── interaction_msgs/                 #   交互控制类消息(msg/srv/action)
│   │   ├── CMakeLists.txt                #     ament_cmake + rosidl(file GLOB)
│   │   ├── package.xml
│   │   └── msg/  srv/  action/
│   ├── robot_msgs/                       #   机器人数据/导航定位类消息(msg/srv)
│   │   ├── CMakeLists.txt                #     ament_cmake + rosidl(file GLOB)
│   │   ├── package.xml
│   │   └── msg/  srv/
│   ├── camera_msgs/                      #   相机云台(PtzStatus)
│   │   ├── CMakeLists.txt                #     ament_cmake + rosidl(file GLOB)
│   │   ├── package.xml
│   │   └── msg/
│   └── sys_monitor_msgs/                 #   设备监控(Camera/Lidar/IMU Status)
│       ├── CMakeLists.txt                #     file GLOB
│       ├── package.xml
│       └── msg/
│
├── example/                              # ★ 示例程序(C++ + Python)
│   ├── cpp/                              #   C++ ament_cmake 包(honor_robot_sdk_examples)
│   │   ├── CMakeLists.txt                #     file(GLOB) 扫描 common/ 与 product/
│   │   ├── build.sh
│   │   ├── package.xml
│   │   ├── common/camera_echo.cpp        #     相机数据订阅
│   │   ├── common/camera_status_echo.cpp #     相机状态订阅(CameraStatus)
│   │   ├── common/joystick_echo.cpp      #     遥控器 Joy 话题监听解析
│   │   ├── common/robot_infos_echo.cpp   #     机器人状态订阅(RobotInfos)
│   │   ├── common/robinfo_service_client.cpp #     机器人信息查询(Trigger 服务,单次调用)
│   │   └── product/.gitkeep              #     产品机型示例(待补充)
│   └── python/                           #   Python 脚本(与 C++ 功能对齐,纯脚本无需编译)
│       ├── common/camera_echo.py
│       ├── common/camera_status_echo.py
│       ├── common/joystick_echo.py
│       ├── common/robot_infos_echo.py
│       ├── common/robinfo_service_client.py
│       └── product/.gitkeep
│
├── lib/                                  # 预编译库(双架构)— 当前占位
│   ├── aarch64/                          #   ARM64(机器人本体)
│   └── x86_64/                           #   x86(开发 PC)
├── docs/                                 # 开发文档(USER_GUIDE 用户指南等)
└── thirdparty/                           # 中间件:iceoryx_cyclone_dds(双架构预编译,随构建打包进 out/)
```

---

## 目录说明

### common/ — 公共交互消息与接口

包含 4 个 ROS2 消息包（`interaction_msgs`/`robot_msgs`/`camera_msgs`/`sys_monitor_msgs`），消息定义与机器人端保持一致。编译方式与机器人端一致——使用 `cmake + make` 通过 `build.sh` 执行，支持 X86 本地编译和交叉编译（Rockchip / Jetson）。

**当前提供的消息包**（各领域可按需裁剪，README 不维护具体计数）：

| 包 | 接口类型 | 说明 |
|----|---------|------|
| **interaction_msgs** | msg + action | 交互控制：运动指令、预置动作、底层关节、机器人状态、头部/运动 action |
| **robot_msgs** | msg + srv | 机器人数据：雷达人体、导航定位、路径录制、建图、机器人信息查询 |
| **camera_msgs** | msg | 相机云台状态（PtzStatus：pan/tilt/zoom） |
| **sys_monitor_msgs** | msg | 设备监控：相机/雷达/IMU 状态 |

#### 接口一览

| 二开需求 | 实现接口 | 包 | 通信方式 |
|----------|---------|-----|---------|
| 控制机器人移动 | `Move.msg` (vx/vy/omega/duration) | interaction_msgs | Topic |
| 预置动作 | `Motion.msg` (squat/standup/balance 等) | interaction_msgs | Topic |
| 运动控制(带反馈) | `Locomotion.action` (action_id+param → result+schedule) | interaction_msgs | Action |
| 底层关节控制 | `LowCommand.msg` + `MotorCommand.msg` | interaction_msgs | Topic |
| 头部控制 | `HeadControl.action` (yaw/pitch) | interaction_msgs | Action |
| 获取机器人状态 | `RobotState.msg` (模式/姿态/速度/方向) | interaction_msgs | Topic |
| 获取关节/电机状态 | `LowState.msg` + `MotorState.msg` | interaction_msgs | Topic |
| 获取机器人信息 | `GetRobotInfo.srv` (产品名/SN/版本/IMEI) | robot_msgs | Service |
| 获取雷达人体 | `LidarHumanInfo.msg` (pose + id) | robot_msgs | Topic |
| 导航状态反馈 | `NavigationStatus.msg` (IDLE/PLANNING/FOLLOWING/REACHED/FAILED) | robot_msgs | Topic |
| 路径录制 | `PathRecordCommand.msg` (START/STOP) + `PathRecordStatus.msg` | robot_msgs | Topic |
| 启动建图 | `StartMapping.srv` | robot_msgs | Service |
| 保存地图 | `StopAndSaveMap.srv` | robot_msgs | Service |
| 设置当前地图 | `SetCurrentWorkingMap.srv` | robot_msgs | Service |
| 启动/停止定位 | `StartLocWithoutPose.srv` / `StartLocWithPose.srv` / `StopLoc.srv` | robot_msgs | Service |
| 获取云台状态 | `PtzStatus.msg` (pan/tilt/zoom) | camera_msgs | Topic |
| 获取相机状态 | `CameraStatus.msg` (RGB/LDP/IR/IMU/CPU 温度·频率·起流) | sys_monitor_msgs | Topic |
| 获取雷达状态 | `LidarStatus.msg` (开关/频率/温度) | sys_monitor_msgs | Topic |
| 获取 IMU 状态 | `IMUStatus.msg` (温度/频率/状态/数据类型) | sys_monitor_msgs | Topic |

> `interaction_msgs` 另包含底层调试与运动参考类消息：`LowCommandDebug`/`LowVerbose`/`MotorVerboseInfo`/`MotorErrCode`/`MotorRecoveryEnable`/`MotionRef`/`ParamKV`，用于底层调试与运动参考回放，详见各 `.msg` 文件。


#### 部分释放说明

4 个包均为"按需挑选对外有用的接口提供，非整包"：

- `sys_monitor_msgs` — 仅提供 `CameraStatus`/`LidarStatus`/`IMUStatus`（设备状态对外可见）。
- `camera_msgs` — 仅提供 `PtzStatus`（云台状态）。

### example/ — 示例程序

按 C++/Python 分离，二级目录按 product 与 common 区分：

- **product/** — 与具体产品机型相关的示例（运动控制、灵巧手、底层关节等），体现"怎么操控这台机器人"
- **common/** — 通用/公共接口示例（状态监控、感知订阅、导航、IMU、遥控器 Joy 话题解析等），体现"怎么获取数据/使用通用服务"

`example/cpp/` 与 `example/python/` 功能对齐，同一示例两种语言各一份。用户直接使用 ROS2 消息通过 topic/service/action 与机器人通信，无需额外 API 封装层：

```cpp
// C++: 直接用 interaction_msgs 发布速度指令
auto pub = node->create_publisher<interaction_msgs::msg::Move>("/honor/locomotion/move", 10);
interaction_msgs::msg::Move msg;
msg.vx = 0.5; msg.vy = 0.0; msg.omega = 0.3;
pub->publish(msg);
```

```python
# Python: 直接用 interaction_msgs 发布速度指令
pub = self.create_publisher(Move, '/honor/locomotion/move', 10)
msg = Move()
msg.vx = 0.5; msg.vy = 0.0; msg.omega = 0.3
pub.publish(msg)
```

#### 已实现示例

| 示例 | 目录 | 说明 | 消息/接口 | 默认 topic |
|------|------|------|-----------|-------------|
| `camera_echo` | `example/cpp/common/` | 订阅髋部 RGBD 彩色图像，打印元数据(编码/分辨率/FPS)，可选保存首帧为 PNG | `sensor_msgs::msg::Image` | `sensor/pelvis_rgbd_color_image` |
| `camera_echo` | `example/python/common/` | 同上 Python 版（纯脚本，功能与 C++ 对齐） | `sensor_msgs::msg::Image` | `sensor/pelvis_rgbd_color_image` |
| `camera_status_echo` | `example/cpp/common/` | 订阅相机状态，打印 RGB/LDP/IR/IMU/CPU 温度·频率·起流等全部字段 | `sys_monitor_msgs::msg::CameraStatus` | `/sensor/pelvis_rgbd_camera_status_param` |
| `camera_status_echo` | `example/python/common/` | 同上 Python 版（纯脚本，功能与 C++ 对齐） | `sys_monitor_msgs::msg::CameraStatus` | `/sensor/pelvis_rgbd_camera_status_param` |
| `joystick_echo` | `example/cpp/common/` | 订阅遥控器 Joy 话题，按 `frame_id` 分派解析打印按键/摇杆值（当前 UniRC，其余留 TODO） | `sensor_msgs::msg::Joy` | `/xlab/hr/joy_state_debug` |
| `joystick_echo` | `example/python/common/` | 同上 Python 版（纯脚本，功能与 C++ 对齐） | `sensor_msgs::msg::Joy` | `/xlab/hr/joy_state_debug` |
| `robot_infos_echo` | `example/cpp/common/` | 订阅机器人状态信息(JSON 文本)，原样打印大脑/小脑 CPU、电池、水泵、电机、传感器、运动模式、定位、运行时长等状态 | `std_msgs::msg::String` | `/shared/robot_infos` |
| `robot_infos_echo` | `example/python/common/` | 同上 Python 版（纯脚本，功能与 C++ 对齐） | `std_msgs::msg::String` | `/shared/robot_infos` |
| `robinfo_service_client` | `example/cpp/common/` | 调用一次机器人信息查询服务(Trigger)，打印返回的 success + message(JSON 状态文本)后退出 | `std_srvs::srv::Trigger` | `/shared/robinfo_service` |
| `robinfo_service_client` | `example/python/common/` | 同上 Python 版（纯脚本，功能与 C++ 对齐） | `std_srvs::srv::Trigger` | `/shared/robinfo_service` |

> 示例中 topic/service 默认值均可通过 ROS2 参数覆盖。

`camera_echo` 只依赖 `rclcpp` + `sensor_msgs`（不依赖本 SDK 消息包），可独立编译。OpenCV + cv_bridge 为可选项：有则编译图像保存功能，无则仅打印元数据。`camera_status_echo` 依赖本 SDK 消息包 `sys_monitor_msgs`，需先构建 `common/` 并 source 其 `setup.bash`（CMake 中设为可选依赖：common 未构建时自动跳过该示例，不影响 `camera_echo` 独立编译）。`product/` 示例依赖 `interaction_msgs`，同样需先构建 `common/`。

`example/cpp` 是独立的 ament_cmake 包（`honor_robot_sdk_examples`），用 `cmake + make` 编译（与 `common/` 一致，非 colcon）。`CMakeLists.txt` 用 `file(GLOB)` 扫描 `common/` 与 `product/` 下的 `.cpp`，**新增示例只需放入对应目录、无需改 CMakeLists**。

### lib/ — 预编译库

按架构分目录存放预编译的 rosidl 生成库（.so 文件），CMake 自动按 `${CMAKE_SYSTEM_PROCESSOR}` 选择架构目录。当前为空（占位），预编译库暂不随 SDK 发布——消息包需从源码构建（见 [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md)）。

- `aarch64/` — ARM64，机器人本体
- `x86_64/` — x86，开发 PC

### docs/ — 开发文档

当前包含 [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md)（用户使用指南）、[`docs/JOYSTICK_ECHO.md`](docs/JOYSTICK_ECHO.md)（遥控器 Joy 话题解析示例说明）。

### thirdparty/ — 中间件

`iceoryx_cyclone_dds/`：基于 iceoryx（共享内存，单机）+ CycloneDDS（网络，多机）的 ROS2 中间件预编译产物，含 `x86_64` / `aarch64` 两套。`./build.sh all` 时自动整体打包进 `out/iceoryx_cyclone_dds/`，供**外接 Ubuntu 笔记本 / 算力板**跨机调试时部署（与机器人本体同源）。部署与配置见 [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) 第 5 节及 `thirdparty/iceoryx_cyclone_dds/README.md`。

---

## 快速开始

### 开发环境要求

| 项目 | 要求 |
|------|------|
| 构建工具 | cmake ≥ 3.12、g++、make |
| ROS2 | Humble（`/opt/ros/humble/setup.bash`） |
| 目标平台 | Linux：aarch64（机器人大脑，Ubuntu 22.04）或 x86_64（开发机/笔记本） |
| Python | python3 ≥ 3.10（机器人本体为 3.10.12；运行 Python 示例，纯脚本无需编译） |
| 网络 | 开发机与机器人大脑可互通（ssh/scp 或 rsync） |

> 交叉编译机器人大脑需对应平台工具链/sysroot（Jetson `/l4t/targetfs`、Rockchip `/rk3588s/sysroot`），详见 [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md)。

### 核心文档索引

| 文档 | 内容 |
|------|------|
| [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) | **用户使用指南**：构建/交叉编译/部署/运行/外接笔记本·算力板调试 |
| [`docs/JOYSTICK_ECHO.md`](docs/JOYSTICK_ECHO.md) | 遥控器 Joy 话题解析示例说明 |
| 本文件「接口一览」 | 主要消息/服务/action 速查 |

### 最短路径：构建 → 运行

```bash
# 1. 构建（X86 本地；交叉编译命令见 USER_GUIDE）
./build.sh all

# 2. 加载环境（先 ROS2 基础，再 SDK overlay）
source out/build_dist/common/setup.bash
source out/build_dist/examples/setup.bash

# 3. 运行示例：订阅相机数据
ros2 run honor_robot_sdk_examples camera_echo
# 或 Python 版
python3 example/python/common/camera_echo.py
```

---

## 构建与使用

### 编译

顶层 `build.sh` 串行编译 `common`（消息包）→ `example`（C++ 示例），统一输出到 `out/`：

```bash
# X86 本地编译
./build.sh all

# 交叉编译(Jetson / l4t)
CROSS_COMPILE=1 ./build.sh all

# 交叉编译(Rockchip rk3588s)
CROSS_COMPILE=rk3588s ./build.sh all

# 清理 out/ 及各子模块 build 产物
./build.sh clean
```

也可单独编译某一模块（`common/build.sh`、`example/cpp/build.sh` 用法一致）：

```bash
cd common && ./build.sh all          # 仅编译消息包
cd example/cpp && ./build.sh all     # 仅编译 C++ 示例
```

> 交叉编译分支：`CROSS_COMPILE=1`/`l4t` 映射为 nvidia Jetson，`rk3588s` 为 Rockchip，留空为 x86 本机。

### 运行示例

```bash
# C++ 示例(camera_echo):source examples overlay 即可(自动带上 common 消息包 + 基础 ROS)
source out/build_dist/examples/setup.bash
ros2 run honor_robot_sdk_examples camera_echo

# 保存首帧为 PNG(需 OpenCV 版本)
ros2 run honor_robot_sdk_examples camera_echo --ros-args -p save_path:=/tmp/frame.png

# 订阅其它相机 topic
ros2 run honor_robot_sdk_examples camera_echo --ros-args -p image_topic:=sensor/pelvis_rgbd_color_image

# C++ 示例(camera_status_echo):订阅相机状态(CameraStatus),依赖 sys_monitor_msgs
ros2 run honor_robot_sdk_examples camera_status_echo
ros2 run honor_robot_sdk_examples camera_status_echo --ros-args -p status_topic:=/sensor/pelvis_rgbd_camera_status_param

# C++ 示例(robot_infos_echo):订阅机器人状态信息(std_msgs/String, JSON 文本)
ros2 run honor_robot_sdk_examples robot_infos_echo
ros2 run honor_robot_sdk_examples robot_infos_echo --ros-args -p robot_infos_topic:=/shared/robot_infos

# C++ 示例(robinfo_service_client):调用一次机器人信息查询服务(std_srvs/Trigger)
ros2 run honor_robot_sdk_examples robinfo_service_client
ros2 run honor_robot_sdk_examples robinfo_service_client --ros-args -p service_name:=/shared/robinfo_service

# Python 示例(纯脚本,无需编译;用到本 SDK 消息包的需先 source common overlay)
source out/build_dist/common/setup.bash
python3 example/python/common/camera_echo.py
python3 example/python/common/camera_status_echo.py
python3 example/python/common/robot_infos_echo.py
python3 example/python/common/robinfo_service_client.py
```

> **环境加载(overlay)**:`out/build_dist/` 下的 `setup.bash` 是构建产物自带的加载脚本。运行前按顺序 source:
>
> 1. `source /opt/ros/humble/setup.bash` —— 基础 ROS
> 2. `source out/build_dist/common/setup.bash` —— SDK 全部消息包
> 3. `source out/build_dist/examples/setup.bash` —— C++ 示例(内部已带上 common,只 source 它即可同时拿到消息包与示例)
>
> 顺序不能反:先 ROS2 基础,再 SDK overlay。source 后 `find_package`(C++)/`import`(Python)才能找到 SDK 消息包,`ros2 run` 才能找到示例可执行。

编译产物路径：
- common：`out/build_dist/common/setup.bash`
- example(C++)：`out/build_dist/examples/setup.bash`
- 中间件(iceoryx + CycloneDDS)：`out/iceoryx_cyclone_dds/`（双架构预编译,外接笔记本/算力板跨机调试用,见 [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) 第 5 节）
- 版本号：`out/VERSION`（如 `1.0.0`，构建时由根目录 `VERSION` 拷入）

---

## 开发规范

### 架构与职责划分

- **本 SDK** —— 提供 ROS2 消息接口 + 示例，让二开程序通过 topic/service/action 与机器人通信，不做 API 封装层。
- **机器人本体** —— 运行传感器/控制器等 ROS2 节点，是消息的生产者/消费者。
- **协作关系** —— 二开程序（运行在机器人大脑、外接笔记本或算力板）作为 ROS2 节点接入，两端通过 DDS 网络通信。

### 标准开发步骤

1. **环境准备**：按 [开发环境要求](#开发环境要求) 搭建（机器人大脑或开发机 + ROS2 Humble）。
2. **构建**：`./build.sh all`（或交叉编译，见 [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md)）。
3. **文档学习**：通读「接口一览」与 [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md)。
4. **示例参考**：看 `example/` 下的 C++ / Python 示例（每个示例两种语言实现）。
5. **集成**：在你的 ROS2 包中 `find_package`（C++）或 `import`（Python）对应消息包。
6. **测试验证**：`ros2 topic list` / `ros2 topic echo <话题> --once` 验证通信。

### 最佳实践

- **source 顺序**：先 `source` ROS2 基础环境，再 `source` SDK overlay（`common/setup.bash` 在 `examples/setup.bash` 之前）。
- **ROS_DOMAIN_ID**：同一网络内的机器人/笔记本/算力板两端需一致（默认 0）。
- **QoS**：订阅方与发布方 QoS 需匹配（示例 `camera_echo` 用 `BEST_EFFORT` + `KEEP_LAST`）。
- **跨机拷贝**：含 `.so` 符号链接的目录（中间件/产物）用 `rsync -aP` 或 tar，勿用 `scp -r`。
- **固件对齐**：机器人固件升级后，请确认 SDK 消息包与机器人端字段一致（必要时重新构建）。

---

## 核心设计原则

1. **common/ 提供 ROS2 消息接口，不做改造** — 消息定义与机器人端一致；编译方式与机器人端一致（`cmake + make` 通过 `build.sh`，支持交叉编译）
2. **不做额外 API 封装层，直接用消息** — 用户直接用 ROS2 topic/service/action 与机器人通信，rosidl 自动生成 C++/Python 绑定
3. **example/ 按 product/common 二级分类** — 区分产品机型示例（怎么操控这台机器人）和通用接口示例（怎么获取数据/使用通用服务）；C++ 与 Python 功能对齐
4. **内外分离** — SDK 只暴露二开需要的接口（部分释放），内部运行时组件不包含在内

---

## 相关文档

- [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) — **用户使用指南:部署到机器人大脑并运行**(构建/交叉编译/部署/运行/外接笔记本·算力板调试)
- [`docs/JOYSTICK_ECHO.md`](docs/JOYSTICK_ECHO.md) — 遥控器 Joy 话题解析示例说明
- [`CHANGELOG.md`](CHANGELOG.md) — 版本变更日志

---

## 版本信息

- **推荐 SDK 版本**：v1.0.0
- **目标系统**：Ubuntu 22.04 + ROS2 Humble（aarch64 / x86_64）
- **文档更新时间**：2026-09-09
