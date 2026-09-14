// camera_echo.cpp
//
// 相机数据订阅示例(用户入门获取数据首选)。
//
// 订阅髋部 RGBD 彩色图像 topic:
//   sensor/pelvis_rgbd_color_image   (sensor_msgs::msg::Image)
//
// 功能:
//   1. 打印图像元数据(frame_id / 时间戳 / 编码 / 分辨率 / 接收 FPS)
//   2. 编译时若检测到 OpenCV,支持把第一帧保存为 PNG(--ros-args -p save_path:=...)
//
// 用法:
//   ros2 run examples camera_echo
//   ros2 run examples camera_echo --ros-args -p image_topic:=sensor/pelvis_rgbd_color_image
//   ros2 run examples camera_echo --ros-args -p save_path:=/tmp/frame.png
//
// 默认 topic 见上;可用 image_topic 参数覆盖。

#include <chrono>
#include <deque>
#include <memory>
#include <string>

#include "rclcpp/rclcpp.hpp"
#include "sensor_msgs/msg/image.hpp"

#ifdef HAVE_OPENCV
#include <cv_bridge/cv_bridge.h>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#endif

class CameraEcho : public rclcpp::Node {
public:
  CameraEcho() : Node("camera_echo") {
    // 默认相机 topic(用户指定)
    image_topic_ = declare_parameter<std::string>(
        "image_topic", "sensor/pelvis_rgbd_color_image");
#ifdef HAVE_OPENCV
    save_path_ = declare_parameter<std::string>("save_path", "");
#else
    declare_parameter<std::string>("save_path", ""); // 占位,避免参数未声明告警
#endif

    auto qos = rclcpp::SensorDataQoS();
    sub_image_ = create_subscription<sensor_msgs::msg::Image>(
        image_topic_, qos,
        std::bind(&CameraEcho::cb_image, this, std::placeholders::_1));

    RCLCPP_INFO(get_logger(), "📸 CameraEcho subscribed: %s",
                image_topic_.c_str());
#ifdef HAVE_OPENCV
    if (!save_path_.empty()) {
      RCLCPP_INFO(get_logger(), "📝 Will save first frame to: %s",
                  save_path_.c_str());
    }
#else
    RCLCPP_INFO(get_logger(),
                "(built without OpenCV: image metadata echo only)");
#endif
  }

private:
  void cb_image(const sensor_msgs::msg::Image::SharedPtr msg) {
    update_arrivals();

    if (should_print()) {
      RCLCPP_INFO(get_logger(),
                  "📸 Image received\n"
                  "  • frame_id:        %s\n"
                  "  • stamp (sec):     %.6f\n"
                  "  • encoding:        %s\n"
                  "  • size (WxH):      %u x %u\n"
                  "  • step (bytes/row):%u\n"
                  "  • recv FPS (1s):   %.1f",
                  msg->header.frame_id.c_str(),
                  rclcpp::Time(msg->header.stamp).seconds(),
                  msg->encoding.c_str(), msg->width, msg->height, msg->step,
                  get_fps());
    }

#ifdef HAVE_OPENCV
    if (!save_path_.empty() && !saved_) {
      save_frame(msg);
    }
#endif
  }

#ifdef HAVE_OPENCV
  void save_frame(const sensor_msgs::msg::Image::SharedPtr &msg) {
    try {
      cv::Mat image = cv_bridge::toCvShare(msg)->image;
      if (msg->encoding == "rgb8") {
        cv::cvtColor(image, image, cv::COLOR_RGB2BGR);
      } else if (msg->encoding == "mono8") {
        cv::cvtColor(image, image, cv::COLOR_GRAY2BGR);
      }
      if (cv::imwrite(save_path_, image)) {
        RCLCPP_INFO(get_logger(), "💾 Saved frame: %s  (%dx%d)",
                    save_path_.c_str(), image.cols, image.rows);
        saved_ = true;
      } else {
        RCLCPP_ERROR(get_logger(), "cv::imwrite failed: %s",
                     save_path_.c_str());
      }
    } catch (const std::exception &e) {
      RCLCPP_WARN(get_logger(), "cv_bridge exception: %s", e.what());
    }
  }
#endif

  // FPS 统计:保留最近 1s 内到达时间戳
  void update_arrivals() {
    const auto now = get_clock()->now();
    arrivals_.push_back(now);
    while (!arrivals_.empty() && (now - arrivals_.front()).seconds() > 1.0) {
      arrivals_.pop_front();
    }
  }
  double get_fps() const { return static_cast<double>(arrivals_.size()); }

  // 限频打印(每秒一次)
  bool should_print() {
    const auto now = get_clock()->now();
    if ((now - last_print_).seconds() >= 1.0) {
      last_print_ = now;
      return true;
    }
    return false;
  }

  std::string image_topic_;
#ifdef HAVE_OPENCV
  std::string save_path_;
  bool saved_{false};
#endif
  rclcpp::Subscription<sensor_msgs::msg::Image>::SharedPtr sub_image_;
  rclcpp::Time last_print_{0, 0, RCL_ROS_TIME};
  std::deque<rclcpp::Time> arrivals_;
};

int main(int argc, char **argv) {
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<CameraEcho>());
  rclcpp::shutdown();
  return 0;
}
