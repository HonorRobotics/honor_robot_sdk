#!/usr/bin/env python3
"""
相机数据订阅示例(与 C++ 版 example/cpp/common/camera_echo.cpp 功能对齐)。

订阅髋部 RGBD 彩色图像 topic:
  sensor/pelvis_rgbd_color_image   (sensor_msgs/Image)

功能:
  1. 打印图像元数据(frame_id / 时间戳 / 编码 / 分辨率 / 接收 FPS)
  2. 若安装了 cv2(cv_bridge),支持把第一帧保存为 PNG(--ros-args -p save_path:=...)

用法:
  ros2 run honor_robot_sdk_examples_py camera_echo
  ros2 run honor_robot_sdk_examples_py camera_echo --ros-args -p image_topic:=sensor/pelvis_rgbd_color_image
  ros2 run honor_robot_sdk_examples_py camera_echo --ros-args -p save_path:=/tmp/frame.png

或直接运行脚本:
  python3 camera_echo.py
  python3 camera_echo.py --ros-args -p image_topic:=sensor/pelvis_rgbd_color_image

默认 topic 见上;可用 image_topic 参数覆盖。
"""

import sys
from collections import deque

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, QoSHistoryPolicy, QoSReliabilityPolicy
from sensor_msgs.msg import Image

# cv2 / cv_bridge 为可选项:有则支持保存首帧 PNG,无则仅打印元数据(与 C++ 版一致)
try:
    from cv_bridge import CvBridge
    import cv2
    HAVE_CV2 = True
except ImportError:
    HAVE_CV2 = False


class CameraEcho(Node):
    def __init__(self):
        super().__init__('camera_echo')

        # 默认相机 topic(用户指定)
        self.declare_parameter('image_topic', 'sensor/pelvis_rgbd_color_image')
        self.declare_parameter('save_path', '')

        self.image_topic = self.get_parameter('image_topic').value
        self.save_path = self.get_parameter('save_path').value

        # SensorDataQoS: BEST_EFFORT + KEEP_LAST(与 C++ rclcpp::SensorDataQoS() 一致)
        qos = QoSProfile(
            reliability=QoSReliabilityPolicy.BEST_EFFORT,
            history=QoSHistoryPolicy.KEEP_LAST,
            depth=5,
        )
        self.sub_image = self.create_subscription(
            Image, self.image_topic, self.cb_image, qos)

        if HAVE_CV2:
            self.bridge = CvBridge()
        self.saved = False

        # FPS 统计 + 限频打印
        self.last_print = self.get_clock().now()
        self.arrivals = deque()

        self.get_logger().info(f'📸 CameraEcho subscribed: {self.image_topic}')
        if HAVE_CV2:
            if self.save_path:
                self.get_logger().info(
                    f'📝 Will save first frame to: {self.save_path}')
        else:
            self.get_logger().info(
                '(cv2 not available: image metadata echo only)')

    # ---- FPS 统计:保留最近 1s 内到达时间戳 ----
    def update_arrivals(self):
        now = self.get_clock().now()
        self.arrivals.append(now)
        while self.arrivals and (now - self.arrivals[0]).nanoseconds * 1e-9 > 1.0:
            self.arrivals.popleft()

    def get_fps(self):
        return len(self.arrivals)

    # ---- 限频打印(每秒一次) ----
    def should_print(self):
        now = self.get_clock().now()
        if (now - self.last_print).nanoseconds * 1e-9 >= 1.0:
            self.last_print = now
            return True
        return False

    # ---- 图像回调 ----
    def cb_image(self, msg: Image):
        self.update_arrivals()

        if self.should_print():
            stamp_sec = msg.header.stamp.sec + msg.header.stamp.nanosec * 1e-9
            self.get_logger().info(
                f'📸 Image received\n'
                f'  • frame_id:        {msg.header.frame_id}\n'
                f'  • stamp (sec):     {stamp_sec:.6f}\n'
                f'  • encoding:        {msg.encoding}\n'
                f'  • size (WxH):      {msg.width} x {msg.height}\n'
                f'  • step (bytes/row):{msg.step}\n'
                f'  • is_bigendian:    {msg.is_bigendian}\n'
                f'  • recv FPS (1s):   {self.get_fps():.1f}'
            )

        if HAVE_CV2 and self.save_path and not self.saved:
            self.save_frame(msg)

    def save_frame(self, msg: Image):
        try:
            image = self.bridge.imgmsg_to_cv2(msg)
            # 统一转 BGR 再保存
            if msg.encoding == 'rgb8':
                image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
            elif msg.encoding == 'mono8':
                image = cv2.cvtColor(image, cv2.COLOR_GRAY2BGR)
            if cv2.imwrite(self.save_path, image):
                self.get_logger().info(
                    f'💾 Saved frame: {self.save_path}  '
                    f'({image.shape[1]}x{image.shape[0]})')
                self.saved = True
            else:
                self.get_logger().error(
                    f'cv2.imwrite failed: {self.save_path}')
        except Exception as e:
            self.get_logger().warn(f'cv_bridge/cv2 exception: {e}')


def main(args=None):
    rclpy.init(args=args)
    node = None
    try:
        node = CameraEcho()
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
