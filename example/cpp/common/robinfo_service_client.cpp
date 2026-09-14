// robinfo_service_client.cpp
//
// 机器人信息查询(service 调用)示例。
//
// 调用机器人信息查询服务:
//   /shared/robinfo_service   (std_srvs::srv::Trigger)
//
// 功能:
//   调用一次该服务拉取机器人状态信息,打印返回的 success 与 message 后退出。
//   Trigger 响应无请求参数;message 通常为 JSON 文本,内容同订阅 /shared/robot_infos
//   的机器人状态信息(大脑/小脑 CPU、电池、水泵、电机、传感器、运动模式、定位、运行时长等)。
//
// 用法:
//   ros2 run honor_robot_sdk_examples robinfo_service_client
//   ros2 run honor_robot_sdk_examples robinfo_service_client --ros-args \
//     -p service_name:=/shared/robinfo_service
//
// 服务名可用参数覆盖。

#include <chrono>
#include <functional>
#include <memory>
#include <string>

#include "rclcpp/rclcpp.hpp"
#include "std_srvs/srv/trigger.hpp"

class RobInfoServiceClient : public rclcpp::Node {
public:
  RobInfoServiceClient() : Node("robinfo_service_client") {
    // 默认服务名
    service_name_ =
        declare_parameter<std::string>("service_name", "/shared/robinfo_service");
    client_ = create_client<std_srvs::srv::Trigger>(service_name_);
  }

  // 等待服务可用并调用一次
  void call_service() {
    while (!client_->wait_for_service(std::chrono::seconds(1))) {
      if (!rclcpp::ok()) {
        RCLCPP_ERROR(get_logger(), "interrupted while waiting for the service: %s",
                     service_name_.c_str());
        return;
      }
      RCLCPP_INFO(get_logger(), "waiting for service %s...",
                  service_name_.c_str());
    }

    // Trigger 无请求参数
    auto request = std::make_shared<std_srvs::srv::Trigger::Request>();
    auto future = client_->async_send_request(
        request, std::bind(&RobInfoServiceClient::cb_response, this,
                           std::placeholders::_1));
    (void)future;
  }

private:
  void cb_response(
      rclcpp::Client<std_srvs::srv::Trigger>::SharedFuture future) {
    try {
      auto response = future.get();
      RCLCPP_INFO(get_logger(),
                  "📋 RobInfoService response\n"
                  "  • success: %s\n"
                  "  • message:\n%s",
                  response->success ? "true" : "false",
                  response->message.c_str());
    } catch (const std::exception &e) {
      RCLCPP_ERROR(get_logger(), "service call failed: %s", e.what());
    }
    rclcpp::shutdown();
  }

  std::string service_name_;
  rclcpp::Client<std_srvs::srv::Trigger>::SharedPtr client_;
};

int main(int argc, char **argv) {
  rclcpp::init(argc, argv);
  auto node = std::make_shared<RobInfoServiceClient>();
  node->call_service();
  rclcpp::spin(node);
  rclcpp::shutdown();
  return 0;
}
