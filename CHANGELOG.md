# Changelog

本 SDK 所有版本变更记录。版本号遵循 [SemVer](https://semver.org/lang/zh-CN/)。

## [v1.0.0] - 2026-09-09

### 新增

- **ROS2 消息包 ×4**：`interaction_msgs`（交互控制）、`robot_msgs`（机器人数据/导航定位）、`camera_msgs`（相机云台）、`sys_monitor_msgs`（设备监控）。
- **SDK 版本机制**：根目录 `VERSION` 文件作为唯一版本来源，构建时输出到 `out/VERSION`。
- **示例程序 ×5**（C++ + Python 双实现）：`camera_echo`、`camera_status_echo`、`robot_infos_echo`、`robinfo_service_client`、`joystick_echo`。
- **双架构中间件打包**：`iceoryx + CycloneDDS` 预编译产物随构建打包进 `out/iceoryx_cyclone_dds/`，支持外接笔记本/算力板跨机调试。
- **文档**：[`docs/USER_GUIDE.md`](docs/USER_GUIDE.md)（含外接笔记本/算力板调试）、[`docs/JOYSTICK_ECHO.md`](docs/JOYSTICK_ECHO.md)。
