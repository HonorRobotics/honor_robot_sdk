// camera_status_echo.cpp
//
// 相机状态(CameraStatus)订阅示例。
//
// 订阅相机状态 topic:
//   /sensor/pelvis_rgbd_camera_status_param   (sys_monitor_msgs::msg::CameraStatus)
//
// 功能:
//   打印相机状态消息的全部字段:设备名 / 时间戳 / RGB / LDP / IR / IMU / CPU。
//   温度字段以 int16 存储,实际温度 = 原值 / 10.0(如 255 => 25.5℃),此处同时打印
//   原始值与换算值。该消息由相机驱动每 2000ms 发布一次,速率较低,故逐帧打印。
//
// 用法:
//   ros2 run examples camera_status_echo
//   ros2 run examples camera_status_echo --ros-args -p status_topic:=/sensor/pelvis_rgbd_camera_status_param
//
// 默认 topic 见上;可用 status_topic 参数覆盖。

#include <memory>
#include <string>

#include "rclcpp/rclcpp.hpp"
#include "sys_monitor_msgs/msg/camera_status.hpp"

class CameraStatusEcho : public rclcpp::Node {
public:
  CameraStatusEcho() : Node("camera_status_echo") {
    // 默认相机状态 topic(髋部 RGBD 相机)
    status_topic_ = declare_parameter<std::string>(
        "status_topic", "/sensor/pelvis_rgbd_camera_status_param");

    // 状态消息为可靠 QoS、深度 10(与发布端一致),避免丢失状态帧
    sub_status_ = create_subscription<sys_monitor_msgs::msg::CameraStatus>(
        status_topic_, rclcpp::QoS(rclcpp::KeepLast(10)),
        std::bind(&CameraStatusEcho::cb_status, this, std::placeholders::_1));

    RCLCPP_INFO(get_logger(), "📊 CameraStatusEcho subscribed: %s",
                status_topic_.c_str());
  }

private:
  void cb_status(const sys_monitor_msgs::msg::CameraStatus::SharedPtr msg) {
    RCLCPP_INFO(get_logger(),
                "📊 CameraStatus received\n"
                "  • device_name:   %s\n"
                "  • frame_id:      %s\n"
                "  • stamp (sec):   %.6f\n"
                "  ---- RGB ----\n"
                "  • rgb_temperature:       %d  (%.1f℃)\n"
                "  • rgb_frequency:         %u Hz\n"
                "  • rgb_switch_status:     %s\n"
                "  • rgb_resolution:        %d x %d\n"
                "  ---- LDP (激光点投影器) ----\n"
                "  • ldp_temperature:       %d  (%.1f℃)\n"
                "  • ldp_switch_status:     %s\n"
                "  • ldp_energy_level:      %u\n"
                "  ---- IR (红外) ----\n"
                "  • ir_left_temperature:   %d  (%.1f℃)\n"
                "  • ir_right_temperature:  %d  (%.1f℃)\n"
                "  • ir_frame_rate:         %u Hz\n"
                "  • ir_switch_status:      %s\n"
                "  • ir_resolution:         %d x %d\n"
                "  ---- IMU ----\n"
                "  • imu_switch_status:     %s\n"
                "  • imu_temperature:       %d  (%.1f℃)\n"
                "  • imu_frequency:         %u Hz\n"
                "  ---- CPU ----\n"
                "  • cpu_temperature:       %d  (%.1f℃)",
                msg->device_name.c_str(), msg->header.frame_id.c_str(),
                rclcpp::Time(msg->header.stamp).seconds(),
                msg->rgb_temperature, msg->rgb_temperature / 10.0,
                static_cast<unsigned>(msg->rgb_frequency),
                msg->rgb_switch_status ? "true(起流)" : "false(未起流)",
                msg->rgb_resolution_width, msg->rgb_resolution_height,
                msg->ldp_temperature, msg->ldp_temperature / 10.0,
                msg->ldp_switch_status ? "true(起流)" : "false(未起流)",
                static_cast<unsigned>(msg->ldp_energy_level),
                msg->ir_left_temperature, msg->ir_left_temperature / 10.0,
                msg->ir_right_temperature, msg->ir_right_temperature / 10.0,
                static_cast<unsigned>(msg->ir_frame_rate),
                msg->ir_switch_status ? "true(起流)" : "false(未起流)",
                msg->ir_resolution_width, msg->ir_resolution_height,
                msg->imu_switch_status ? "true(起流)" : "false(未起流)",
                msg->imu_temperature, msg->imu_temperature / 10.0,
                static_cast<unsigned>(msg->imu_frequency), msg->cpu_temperature,
                msg->cpu_temperature / 10.0);
  }

  std::string status_topic_;
  rclcpp::Subscription<sys_monitor_msgs::msg::CameraStatus>::SharedPtr
      sub_status_;
};

int main(int argc, char **argv) {
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<CameraStatusEcho>());
  rclcpp::shutdown();
  return 0;
}
