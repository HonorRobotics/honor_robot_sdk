// robot_infos_echo.cpp
//
// 机器人信息(RobotInfos)订阅示例。
//
// 订阅机器人状态信息 topic:
//   /shared/robot_infos   (std_msgs::msg::String)
//
// 功能:
//   打印机器人运行状态信息。消息以 JSON 文本形式承载于 std_msgs/String,
//   覆盖大脑/小脑 CPU、主/副电池、水泵、电机、传感器、运动模式、定位、运行时长等
//   模块状态。本示例直接原样打印 JSON 文本;如需结构化解析,可按需引入
//   JSON 解析库(如 nlohmann/json)后按字段读取。
//
//   典型 JSON 顶层字段:
//     brain_cpu_details      大脑 CPU(核占用/温度/RAM/存储)
//     cerebellum_cpu_details 小脑 CPU(同上)
//     main_battery_details   主电池(电量/温度/错误/MOS/回收/低电量)
//     sub_battery_details    副电池(同上)
//     pump_details           水泵(泵/风扇/温度)
//     motor_details          电机(电流等 + 高温告警)
//     sensor_details         传感器(IMU/RGBD/RGB/雷达/RTK/SLAM/车道)
//     sport_details          运动模式/速度
//     location_details       定位(lon_infos)
//     run_time               运行时长(startups/shutdowns/lifetime/current)
//
// 用法:
//   ros2 run honor_robot_sdk_examples robot_infos_echo
//   ros2 run honor_robot_sdk_examples robot_infos_echo --ros-args -p robot_infos_topic:=/shared/robot_infos
//
// 该 topic 为低频状态信息(秒级),逐帧打印即可。

#include <memory>
#include <string>

#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"

class RobotInfosEcho : public rclcpp::Node {
public:
  RobotInfosEcho() : Node("robot_infos_echo") {
    // 机器人状态信息默认 topic
    robot_infos_topic_ = declare_parameter<std::string>(
        "robot_infos_topic", "/shared/robot_infos");

    // 状态信息为可靠 QoS、深度 10(与发布端一致),避免丢失状态帧
    sub_robot_infos_ = create_subscription<std_msgs::msg::String>(
        robot_infos_topic_, rclcpp::QoS(rclcpp::KeepLast(10)),
        std::bind(&RobotInfosEcho::cb_robot_infos, this,
                  std::placeholders::_1));

    RCLCPP_INFO(get_logger(), "📋 RobotInfosEcho subscribed: %s",
                robot_infos_topic_.c_str());
  }

private:
  void cb_robot_infos(const std_msgs::msg::String::SharedPtr msg) {
    // 消息内容为 JSON 文本,原样打印
    RCLCPP_INFO(get_logger(), "📋 RobotInfos received:\n%s", msg->data.c_str());
  }

  std::string robot_infos_topic_;
  rclcpp::Subscription<std_msgs::msg::String>::SharedPtr sub_robot_infos_;
};

int main(int argc, char **argv) {
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<RobotInfosEcho>());
  rclcpp::shutdown();
  return 0;
}
