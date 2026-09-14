#!/usr/bin/env python3
"""
相机状态(CameraStatus)订阅示例(与 C++ 版 example/cpp/common/camera_status_echo.cpp 功能对齐)。

订阅相机状态 topic:
  /sensor/pelvis_rgbd_camera_status_param   (sys_monitor_msgs/CameraStatus)

功能:
  打印相机状态消息的全部字段:设备名 / 时间戳 / RGB / LDP / IR / IMU / CPU。
  温度字段以 int16 存储,实际温度 = 原值 / 10.0(如 255 => 25.5℃),此处同时打印
  原始值与换算值。该消息由相机驱动每 2000ms 发布一次,速率较低,故逐帧打印。

用法:
  ros2 run honor_robot_sdk_examples_py camera_status_echo
  ros2 run honor_robot_sdk_examples_py camera_status_echo --ros-args -p status_topic:=/sensor/pelvis_rgbd_camera_status_param

或直接运行脚本:
  python3 camera_status_echo.py
  python3 camera_status_echo.py --ros-args -p status_topic:=/sensor/pelvis_rgbd_camera_status_param

默认 topic 见上;可用 status_topic 参数覆盖。
"""

import sys

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, QoSHistoryPolicy, QoSReliabilityPolicy
from sys_monitor_msgs.msg import CameraStatus


class CameraStatusEcho(Node):
    def __init__(self):
        super().__init__('camera_status_echo')

        # 默认相机状态 topic(髋部 RGBD 相机)
        self.declare_parameter('status_topic',
                               '/sensor/pelvis_rgbd_camera_status_param')
        self.status_topic = self.get_parameter('status_topic').value

        # 状态消息为可靠 QoS、深度 10(与发布端一致),避免丢失状态帧
        qos = QoSProfile(
            reliability=QoSReliabilityPolicy.RELIABLE,
            history=QoSHistoryPolicy.KEEP_LAST,
            depth=10,
        )
        self.sub_status = self.create_subscription(
            CameraStatus, self.status_topic, self.cb_status, qos)

        self.get_logger().info(
            f'📊 CameraStatusEcho subscribed: {self.status_topic}')

    # ---- 状态回调:逐帧打印(消息 0.5Hz,无需限频) ----
    def cb_status(self, msg: CameraStatus):
        stamp_sec = msg.header.stamp.sec + msg.header.stamp.nanosec * 1e-9

        # bool 起流状态统一转中文描述
        def sw(on: bool) -> str:
            return 'true(起流)' if on else 'false(未起流)'

        self.get_logger().info(
            f'📊 CameraStatus received\n'
            f'  • device_name:   {msg.device_name}\n'
            f'  • frame_id:      {msg.header.frame_id}\n'
            f'  • stamp (sec):   {stamp_sec:.6f}\n'
            f'  ---- RGB ----\n'
            f'  • rgb_temperature:       {msg.rgb_temperature}  '
            f'({msg.rgb_temperature / 10.0:.1f}℃)\n'
            f'  • rgb_frequency:         {msg.rgb_frequency} Hz\n'
            f'  • rgb_switch_status:     {sw(msg.rgb_switch_status)}\n'
            f'  • rgb_resolution:        {msg.rgb_resolution_width} x '
            f'{msg.rgb_resolution_height}\n'
            f'  ---- LDP (激光点投影器) ----\n'
            f'  • ldp_temperature:       {msg.ldp_temperature}  '
            f'({msg.ldp_temperature / 10.0:.1f}℃)\n'
            f'  • ldp_switch_status:     {sw(msg.ldp_switch_status)}\n'
            f'  • ldp_energy_level:      {msg.ldp_energy_level}\n'
            f'  ---- IR (红外) ----\n'
            f'  • ir_left_temperature:   {msg.ir_left_temperature}  '
            f'({msg.ir_left_temperature / 10.0:.1f}℃)\n'
            f'  • ir_right_temperature:  {msg.ir_right_temperature}  '
            f'({msg.ir_right_temperature / 10.0:.1f}℃)\n'
            f'  • ir_frame_rate:         {msg.ir_frame_rate} Hz\n'
            f'  • ir_switch_status:      {sw(msg.ir_switch_status)}\n'
            f'  • ir_resolution:         {msg.ir_resolution_width} x '
            f'{msg.ir_resolution_height}\n'
            f'  ---- IMU ----\n'
            f'  • imu_switch_status:     {sw(msg.imu_switch_status)}\n'
            f'  • imu_temperature:       {msg.imu_temperature}  '
            f'({msg.imu_temperature / 10.0:.1f}℃)\n'
            f'  • imu_frequency:         {msg.imu_frequency} Hz\n'
            f'  ---- CPU ----\n'
            f'  • cpu_temperature:       {msg.cpu_temperature}  '
            f'({msg.cpu_temperature / 10.0:.1f}℃)'
        )


def main(args=None):
    rclpy.init(args=args)
    node = None
    try:
        node = CameraStatusEcho()
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
