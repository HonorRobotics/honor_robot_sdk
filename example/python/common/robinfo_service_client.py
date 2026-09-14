#!/usr/bin/env python3
"""
机器人信息查询(service 调用)示例(与 C++ 版 example/cpp/common/robinfo_service_client.cpp 功能对齐)。

调用机器人信息查询服务:
  /shared/robinfo_service   (std_srvs/Trigger)

功能:
  调用一次该服务拉取机器人状态信息,打印返回的 success 与 message 后退出。
  Trigger 响应无请求参数;message 通常为 JSON 文本,内容同订阅 /shared/robot_infos
  的机器人状态信息(大脑/小脑 CPU、电池、水泵、电机、传感器、运动模式、定位、运行时长等)。

用法:
  python3 robinfo_service_client.py
  python3 robinfo_service_client.py --ros-args -p service_name:=/shared/robinfo_service

服务名可用参数覆盖。
"""

import sys

import rclpy
from rclpy.node import Node
from std_srvs.srv import Trigger


class RobInfoServiceClient(Node):
    def __init__(self):
        super().__init__('robinfo_service_client')

        # 默认服务名
        self.declare_parameter('service_name', '/shared/robinfo_service')
        self.service_name = self.get_parameter('service_name').value

        self.cli = self.create_client(Trigger, self.service_name)

    # ---- 等待服务可用并调用一次 ----
    def call_service(self):
        while not self.cli.wait_for_service(timeout_sec=1.0):
            if not rclpy.ok():
                self.get_logger().error(
                    f'interrupted while waiting for the service: '
                    f'{self.service_name}')
                return
            self.get_logger().info(
                f'waiting for service {self.service_name}...')

        # Trigger 无请求参数
        req = Trigger.Request()
        future = self.cli.call_async(req)
        rclpy.spin_until_future_complete(self, future)

        if future.result() is not None:
            resp = future.result()
            self.get_logger().info(
                f'📋 RobInfoService response\n'
                f'  • success: {resp.success}\n'
                f'  • message:\n{resp.message}')
        else:
            self.get_logger().error('service call failed')
            if future.exception() is not None:
                self.get_logger().error(f'{future.exception()}')


def main(args=None):
    rclpy.init(args=args)
    node = None
    try:
        node = RobInfoServiceClient()
        node.call_service()
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
