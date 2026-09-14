cmake_minimum_required(VERSION 3.12)
project(sys_monitor_msgs)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)
find_package(rosidl_default_generators REQUIRED)
find_package(std_msgs REQUIRED)

# 用 file(GLOB) 自动纳入 msg/srv(与源仓一致,新增/删除文件自动生效)
FILE(GLOB msg_files
  RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}/
  msg/*.msg
)

FILE(GLOB srv_files
  RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}/
  srv/*.srv
)

rosidl_generate_interfaces(${PROJECT_NAME}
  ${msg_files} ${srv_files}
  DEPENDENCIES std_msgs
)
ament_export_dependencies(rosidl_default_runtime)
ament_package()
