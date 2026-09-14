# joystick话题监听解析示例（joystick_echo.cpp和joystick_echo.py使用说明）

本示例（`joystick_echo.cpp`或`joystick_echo.py`）订阅机器人发布的 `sensor_msgs/msg/Joy` 话题
`/xlab/hr/joy_state_debug`（100Hz 常发），按消息 `header.frame_id` 判断遥控器
类型，解析并打印按键与摇杆值。

## 文件说明

| 文件 | 说明 |
|---|---|
| `example/cpp/common/joystick_echo.cpp` | C++ 示例（rclcpp，C++17），随 SDK 主构建编译 |
| `example/python/common/joystick_echo.py` | Python 示例（rclpy），板端/开发机直接运行 |


## 话题消息格式

订阅的话题`/xlab/hr/joy_state_debug`消息类型为 `sensor_msgs/msg/Joy` ，包含三个关键字段：

| 字段 | 类型 | 含义 |
|---|---|---|
| `header.frame_id` | `string` | 遥控器类型名（例如 `"UniRC"`），示例据此选择解析方式 |
| `axes` | `float32[]` | 摇杆轴值数组，见「摇杆轴」 |
| `buttons` | `int32[]` | 按键位图数组，本示例用 `buttons[0]` 一个 int32 位图表示全部按键，见「按键位图」 |

### 摇杆轴 axes

| 下标 | 轴名 | 含义 | 说明 |
|---|---|---|---|
| 0 | lx | 左摇杆前后 | 范围 [-1, 1] |
| 1 | ly | 左摇杆左右 | 范围 [-1, 1] |
| 2 | rx | 右摇杆前后 | omega UniRC 未使用，恒为 0 |
| 3 | ry | 右摇杆左右 | 范围 [-1, 1] |
| 4 | wave | 拨轮 | omega UniRC 未使用，恒为 0 |


### 按键位图 buttons[0]

`buttons[0]` 是一个 32 位位图（int32），每一位代表一个按键，位为 1 表示按下。
**不同遥控器型号的位图映射规则不同**，下面以当前已支持的 UniRC 为例说明。

#### UniRC 按键位图映射

| 按键 | key_map 掩码 | 备注 |
|---|---|---|
| S1 | `1 << 9` | 单 bit 键 |
| S2 | `1 << 8` | 单 bit 键 |
| M1 | `1 << 3` | 单 bit 键 |
| M2 | `1 << 2` | 单 bit 键 |
| M3 | `1 << 16` | 单 bit 键 |
| L1 | `1 << 14` | 单 bit 键 |
| L2 | `1 << 15` | 单 bit 键 |
| S3 | `1 << 18` | 单 bit 键 |
| S4 | `1 << 17` | 单 bit 键 |
| R1 | `(1 << 6) \| (1 << 13)` | 双 bit 键 |
| R2 | `(1 << 7) \| (1 << 11)` | 双 bit 键 |
| R3 | `(1 << 4) \| (1 << 12)` | 双 bit 键 |
| M6 | `(1 << 5) \| (1 << 10)` | 双 bit 键 |

> 双 bit 键（R1/R2/R3/M6）的判定：两个 bit 同时为 1 才算按下。


## 脚本代码结构

### Python 示例（joystick_echo.py）

- `JOY_TOPIC`：机器人发布的 Joy 话题名称；
- **各遥控器型号配置**：`UNI_RC_KEYS` / `UNI_RC_AXES_NAMES`（UniRC 的按键位图表与
  轴名表，各型号不同）、`PARSERS`（遥控器类型名 → `(按键位图, 轴名)` 的配置映射表，
  新增型号只需在此增加一份配置并注册）；
- **通用解析**：`parse(msg, keys, axes_names)`，接收按键位图与轴名作为参数，从
  `buttons[0]` 提取按键位图、解析摇杆值与按键状态并返回字符串（所有型号通用，无需修改）；
- **ROS 节点与入口**：`JoystickEchoNode`（构造时订阅话题，回调 `joy_callback` 里按
  `frame_id` 查表取配置，再调用 `parse()` 解析并打印）、`main()`。

### C++ 示例（joystick_echo.cpp）

结构与 Python 版一一对应：

- `JOY_TOPIC`：机器人发布的 Joy 话题名称；
- **类型结构定义**：`ParseResult`（轴值字符串 + 按键字符串）、`KeyDef`（单个按键位图）、
  `ParserConfig`（按键位图 + 轴名）；
- **各遥控器型号配置**：`UNI_RC_KEYS` / `UNI_RC_AXES_NAMES`（UniRC 的按键位图与轴名
  常量，各型号不同）、`PARSERS`（`frame_id` → `ParserConfig` 的配置映射表，新增型号
  只需在此增加一份配置并注册）；
- **通用解析**：`Parse(msg, config)`，接收解析配置作为参数，从 `buttons[0]` 提取按键
  位图、解析摇杆值与按键状态并返回 `ParseResult`（所有型号通用，无需修改）；
- **ROS 节点与入口**：`JoystickEchoNode`（构造时订阅话题，回调 `JoyCallback` 里查表
  取配置，再调用 `Parse()` 解析并打印）、`main()`。


## 构建与运行方式

### C++ 示例

C++ 示例位于 `example/cpp/common/`，由 SDK 示例包的 `file(GLOB)` 自动扫描编译
（新增 `.cpp` 无需改 CMakeLists），随 SDK 顶层 `build.sh` 一并构建。构建后运行：

```bash
source <out>/build_dist/examples/setup.bash
ros2 run honor_robot_sdk_examples joystick_echo
```

### Python 示例

板端（或与板端同 ROS 网络的开发机）：

```bash
source /opt/ros/humble/setup.bash
python3 example/python/common/joystick_echo.py
```

## 输出样例

frame_id 匹配到正确的解析配置时（以UniRC为例）：

```text
[joy] frame_id: UniRC
[joy] axes: lx=-0.12 ly=0.00 rx=0.00 ry=-0.45
[joy] buttons: S1=1 S2=1 M1=0 M2=0 M3=0 M6=0 R1=0 R2=0 R3=0 L1=0 L2=0 S3=0 S4=0
```

frame_id 没有匹配的解析配置时：

```text
[joy] frame_id: OtherRC (unsupported type, raw buttons[0]=0x300)
```
