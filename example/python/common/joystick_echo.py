#!/usr/bin/env python3
"""
遥控器 Joy 话题监听解析示例(与 C++ 版 example/cpp/common/joystick_echo.cpp 功能对齐)。

订阅机器人发布的 Joy 话题:
  /xlab/hr/joy_state_debug   (sensor_msgs/msg/Joy, 100Hz 常发)

功能:
  1. 按 header.frame_id 判断遥控器类型,分派到对应解析配置打印按键与摇杆值;
  2. 通用解析逻辑与各型号按键位图/轴名配置分离,新增型号只需增加配置并注册。

用法:
  python3 joystick_echo.py

frame_id 为遥控器类型名(如 "UniRC"),示例据此选择解析配置。
扩展方式:新增一份按键位图与轴名配置,并在 PARSERS 表中以 frame_id 为键注册即可。
"""

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Joy

# 机器人发布的Joy话题名称
JOY_TOPIC = "/xlab/hr/joy_state_debug"

# ==================== 各遥控器型号配置 ====================

# UniRC 遥控器 key_map 位定义(单 bit 键占 1 位;双 bit 键占 2 位)。
# 双 bit 键(R1/R2/R3/M6)按完整掩码判定:两个 bit 同时置位才算按下。
UNI_RC_KEYS = [
    ("S1", 1 << 9),
    ("S2", 1 << 8),
    ("M1", 1 << 3),
    ("M2", 1 << 2),
    ("M3", 1 << 16),
    ("M6", (1 << 5) | (1 << 10)),
    ("R1", (1 << 6) | (1 << 13)),
    ("R2", (1 << 7) | (1 << 11)),
    ("R3", (1 << 4) | (1 << 12)),
    ("L1", 1 << 14),
    ("L2", 1 << 15),
    ("S3", 1 << 18),
    ("S4", 1 << 17),
]

# UniRC 遥控器四轴摇杆
UNI_RC_AXES_NAMES = ["lx", "ly", "rx", "ry"]

# 遥控器类型 -> (按键位图, 轴名)。新增型号时在此以 frame_id 为键注册即可。
PARSERS = {
    "UniRC": (UNI_RC_KEYS, UNI_RC_AXES_NAMES),
}

# ==================== 通用解析:按按键位图与轴名解析 Joy 消息 ====================
def parse(msg, keys, axes_names):
    """按按键位图与轴名解析 Joy 消息,返回 (axes_str, buttons_str)。"""
    # 从 buttons[0] 提取 32 位按键状态
    key_map = msg.buttons[0] if msg.buttons else 0

    # 解析摇杆值
    axes = list(msg.axes) + [0.0] * (len(axes_names) - len(msg.axes))
    axes_str = " ".join(
        ["{}={:.2f}".format(name, axes[i])
         for i, name in enumerate(axes_names)])

    # 解析按键状态
    buttons_str = " ".join(
        ["{}={}".format(name, int((key_map & mask) == mask))
         for name, mask in keys])
    return axes_str, buttons_str


# ==================== ROS节点与入口 ====================

class JoystickEchoNode(Node):

    def __init__(self):
        super().__init__("joystick_echo")
        # 创建订阅者，订阅 Joy 话题
        self.create_subscription(Joy, JOY_TOPIC, self.joy_callback, 10)
        self.get_logger().info("subscribed topic: {}".format(JOY_TOPIC))

    def joy_callback(self, msg):
        joy_type = msg.header.frame_id
        config = PARSERS.get(joy_type)  # 查找解析配置
        if config is None:  # 如果找不到对应解析器，打印原始数据
            key_map = msg.buttons[0] if msg.buttons else 0
            print("[joy] frame_id: {} (unsupported type, raw buttons[0]={:#x})".format(
                joy_type, key_map))
            return

        # 调用通用解析
        keys, axes_names = config
        axes_str, buttons_str = parse(msg, keys, axes_names)
        print("[joy] frame_id: {}".format(joy_type))
        print("[joy] axes: {}".format(axes_str))
        print("[joy] buttons: {}".format(buttons_str))


def main(args=None):
    rclpy.init(args=args)
    node = JoystickEchoNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == "__main__":
    main()
