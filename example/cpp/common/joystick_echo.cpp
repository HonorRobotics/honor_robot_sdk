// joystick_echo.cpp
//
// 遥控器 Joy 话题监听解析示例(用户二开获取遥控器按键/摇杆值首选)。
//
// 订阅机器人发布的 Joy 话题:
//   /xlab/hr/joy_state_debug   (sensor_msgs::msg::Joy, 100Hz 常发)
//
// 功能:
//   1. 按 header.frame_id 判断遥控器类型,分派到对应解析配置打印按键与摇杆值;
//   2. 通用解析逻辑与各型号按键位图/轴名配置分离,新增型号只需增加配置并注册。
//
// 用法(SDK):
//   source <out>/build_dist/examples/setup.bash
//   ros2 run honor_robot_sdk_examples joystick_echo
//
// frame_id 为遥控器类型名(如 "UniRC"),示例据此选择解析配置。
// 扩展方式:新增一份按键位图与轴名配置,并在 PARSERS 表中以 frame_id 为键注册即可。

#include <cstdint>
#include <iomanip>
#include <iostream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

#include "rclcpp/rclcpp.hpp"
#include "sensor_msgs/msg/joy.hpp"

namespace {

// 机器人发布的Joy话题名称
constexpr const char* JOY_TOPIC = "/xlab/hr/joy_state_debug";

// ==================== 类型结构定义 ====================

// 解析结果:轴值字符串与按键字符串
struct ParseResult {
    std::string axes;
    std::string buttons;
};

// 单个按键的位图定义
struct KeyDef {
    const char* name;
    uint32_t mask;
};

// 单款遥控器的解析配置:按键位图 + 轴名
struct ParserConfig {
    std::vector<KeyDef> keys;
    std::vector<std::string> axesNames;
};

// ==================== 各遥控器型号配置 ====================

// UniRC 遥控器 key_map 位定义(单 bit 键占 1 位;双 bit 键占 2 位)。
// 双 bit 键(R1/R2/R3/M6)按完整掩码判定:两个 bit 同时置位才算按下。
const std::vector<KeyDef> UNI_RC_KEYS = {
    {"S1", 1U << 9},  {"S2", 1U << 8},  {"M1", 1U << 3},  {"M2", 1U << 2},
    {"M3", 1U << 16}, {"M6", (1U << 5) | (1U << 10)},
    {"R1", (1U << 6) | (1U << 13)},
    {"R2", (1U << 7) | (1U << 11)},
    {"R3", (1U << 4) | (1U << 12)},
    {"L1", 1U << 14}, {"L2", 1U << 15}, {"S3", 1U << 18}, {"S4", 1U << 17},
};

// UniRC 遥控器四轴摇杆
const std::vector<std::string> UNI_RC_AXES_NAMES = {"lx", "ly", "rx", "ry"};

// 遥控器类型 -> 解析配置。新增型号时在此以 frame_id 为键注册即可。
const std::map<std::string, ParserConfig> PARSERS = {
    {"UniRC", {UNI_RC_KEYS, UNI_RC_AXES_NAMES}},
};


// ==================== 通用解析:按解析配置解析 Joy 消息 ====================
ParseResult Parse(const sensor_msgs::msg::Joy& msg, const ParserConfig& config)
{
    // 从 buttons[0] 提取 32 位按键状态
    uint32_t keyMap = msg.buttons.empty() ? 0U : static_cast<uint32_t>(msg.buttons[0]);

    // 解析摇杆值
    std::ostringstream axes;
    axes << std::fixed << std::setprecision(2);
    for (size_t i = 0; i < config.axesNames.size(); ++i) {
        if (i > 0) {
            axes << " ";
        }
        float value = (i < msg.axes.size()) ? msg.axes[i] : 0.0f;
        axes << config.axesNames[i] << "=" << value;
    }

    // 解析按键状态
    std::ostringstream buttons;
    for (size_t i = 0; i < config.keys.size(); ++i) {
        if (i > 0) {
            buttons << " ";
        }
        buttons << config.keys[i].name << "="
                << ((keyMap & config.keys[i].mask) == config.keys[i].mask ? 1 : 0);
    }

    return {axes.str(), buttons.str()};
}

}  // namespace

// ==================== ROS节点与入口 ====================

class JoystickEchoNode : public rclcpp::Node {
public:
    JoystickEchoNode() : Node("joystick_echo")
    {
        // 创建订阅者,订阅 Joy 话题
        subscription_ = create_subscription<sensor_msgs::msg::Joy>(
            JOY_TOPIC, 10,
            [this](const sensor_msgs::msg::Joy::SharedPtr msg) { JoyCallback(msg); });
        RCLCPP_INFO(get_logger(), "subscribed topic: %s", JOY_TOPIC);
    }

private:
    void JoyCallback(const sensor_msgs::msg::Joy::SharedPtr msg)
    {
        auto it = PARSERS.find(msg->header.frame_id);  // 查找解析配置
        if (it == PARSERS.end()) {  // 未注册的遥控器类型,打印原始数据
            uint32_t keyMap = msg->buttons.empty() ? 0U : static_cast<uint32_t>(msg->buttons[0]);
            std::cout << "[joy] frame_id: " << msg->header.frame_id
                      << " (unsupported type, raw buttons[0]=" << std::hex << std::showbase
                      << keyMap << std::dec << std::noshowbase << ")" << std::endl;
            return;
        }

        // 调用通用解析
        ParseResult result = Parse(*msg, it->second);
        std::cout << "[joy] frame_id: " << msg->header.frame_id << std::endl;
        std::cout << "[joy] axes: " << result.axes << std::endl;
        std::cout << "[joy] buttons: " << result.buttons << std::endl;
    }

    rclcpp::Subscription<sensor_msgs::msg::Joy>::SharedPtr subscription_;
};

int main(int argc, char* argv[])
{
    rclcpp::init(argc, argv);
    rclcpp::spin(std::make_shared<JoystickEchoNode>());
    rclcpp::shutdown();
    return 0;
}
