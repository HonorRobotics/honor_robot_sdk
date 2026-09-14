#!/usr/bin/env python3
"""
机器人信息(RobotInfos)订阅示例(与 C++ 版 example/cpp/common/robot_infos_echo.cpp 功能对齐)。

订阅机器人状态信息 topic:
  /shared/robot_infos   (std_msgs/String)

功能:
  打印机器人运行状态信息。消息以 JSON 文本形式承载于 std_msgs/String,
  覆盖大脑/小脑 CPU、主/副电池、水泵、电机、传感器、运动模式、定位、运行时长等
  模块状态。本示例直接原样打印 JSON 文本;如需结构化解析,可用内置 json 模块
  反序列化后按字段读取,例如:
    data = json.loads(msg.data)
    data['main_battery_details']['battery_percent']

  典型 JSON 顶层字段:
    brain_cpu_details      大脑 CPU(核占用/温度/RAM/存储)
    cerebellum_cpu_details 小脑 CPU(同上)
    main_battery_details   主电池(电量/温度/错误/MOS/回收/低电量)
    sub_battery_details    副电池(同上)
    pump_details           水泵(泵/风扇/温度)
    motor_details          电机(电流等 + 高温告警)
    sensor_details         传感器(IMU/RGBD/RGB/雷达/RTK/SLAM/车道)
    sport_details          运动模式/速度
    location_details       定位(lon_infos)
    run_time               运行时长(startups/shutdowns/lifetime/current)

用法:
  python3 robot_infos_echo.py
  python3 robot_infos_echo.py --ros-args -p robot_infos_topic:=/shared/robot_infos

topic 可用 robot_infos_topic 参数覆盖。
"""

import sys

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, QoSHistoryPolicy, QoSReliabilityPolicy
from std_msgs.msg import String


class RobotInfosEcho(Node):
    def __init__(self):
        super().__init__('robot_infos_echo')

        # 机器人状态信息默认 topic
        self.declare_parameter('robot_infos_topic', '/shared/robot_infos')
        self.robot_infos_topic = self.get_parameter('robot_infos_topic').value

        # 状态信息为可靠 QoS、深度 10(与发布端一致),避免丢失状态帧
        qos = QoSProfile(
            reliability=QoSReliabilityPolicy.RELIABLE,
            history=QoSHistoryPolicy.KEEP_LAST,
            depth=10,
        )
        self.sub_robot_infos = self.create_subscription(
            String, self.robot_infos_topic, self.cb_robot_infos, qos)

        self.get_logger().info(
            f'📋 RobotInfosEcho subscribed: {self.robot_infos_topic}')

    # ---- 状态回调:逐帧打印(消息为秒级低频状态信息,无需限频) ----
    def cb_robot_infos(self, msg: String):
        # 消息内容为 JSON 文本,原样打印(与 C++ 版一致)
        self.get_logger().info(f'📋 RobotInfos received:\n{msg.data}')


def main(args=None):
    rclpy.init(args=args)
    node = None
    try:
        node = RobotInfosEcho()
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    except Exception as e:
        print(f'Error: {e}', file=sys.stderr)
    finally:
        if node is not None:
            node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == '__main__':
    main()
