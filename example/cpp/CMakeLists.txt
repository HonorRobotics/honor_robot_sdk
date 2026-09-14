cmake_minimum_required(VERSION 3.12)
project(honor_robot_sdk_examples)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# ---------------- 基础依赖 ----------------
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(sensor_msgs REQUIRED)
find_package(std_msgs REQUIRED)
find_package(std_srvs REQUIRED)
# sys_monitor_msgs(本 SDK common/ 消息包,定义 CameraStatus 等)用于相机状态订阅示例。
# 设为可选:common 未构建时跳过 camera_status_echo,保留 camera_echo 等独立编译能力。
find_package(sys_monitor_msgs QUIET)
if(sys_monitor_msgs_FOUND)
  message(STATUS "sys_monitor_msgs found: camera_status_echo enabled")
else()
  message(STATUS "sys_monitor_msgs not found: camera_status_echo will be skipped (build common/ first)")
endif()

# OpenCV + cv_bridge 为可选项:有则编译图像保存功能,无则仅打印元数据
find_package(OpenCV QUIET COMPONENTS core imgproc imgcodecs)
find_package(cv_bridge QUIET)
if(OpenCV_FOUND AND cv_bridge_FOUND)
  set(HAVE_OPENCV TRUE)
  message(STATUS "OpenCV + cv_bridge found: image save enabled")
else()
  set(HAVE_OPENCV FALSE)
  message(STATUS "OpenCV/cv_bridge not found: image metadata echo only")
endif()

# ---------------- common/ 示例 (file(GLOB) 自动扫描,新增 .cpp 无需改本文件) ----------------
file(GLOB COMMON_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_LIST_DIR}/common/*.cpp)

foreach(file ${COMMON_SOURCES})
  get_filename_component(filename ${file} NAME_WE)

  # camera_status_echo 依赖 sys_monitor_msgs;common 未构建时跳过该示例
  # (camera_echo 等仅依赖 rclcpp + sensor_msgs,仍可独立编译)
  if(filename STREQUAL "camera_status_echo" AND NOT sys_monitor_msgs_FOUND)
    message(STATUS "skip executable: ${filename} (sys_monitor_msgs not found)")
    continue()
  endif()

  message(STATUS "add executable: ${filename}")
  add_executable(${filename} ${file})

  ament_target_dependencies(${filename} rclcpp sensor_msgs std_msgs std_srvs)
  if(filename STREQUAL "camera_status_echo")
    ament_target_dependencies(${filename} sys_monitor_msgs)
  endif()

  if(HAVE_OPENCV)
    target_compile_definitions(${filename} PRIVATE HAVE_OPENCV)
    ament_target_dependencies(${filename} cv_bridge)
    target_include_directories(${filename} PRIVATE ${OpenCV_INCLUDE_DIRS})
    target_link_libraries(${filename} ${OpenCV_LIBS})
  endif()

  install(TARGETS ${filename} DESTINATION lib/${PROJECT_NAME})
endforeach()

# ---------------- product/ 示例 (file(GLOB) 自动扫描,新增 .cpp 无需改本文件) ----------------
# product/ 示例依赖 interaction_msgs(本 SDK common/ 消息包),需先构建 common 并
# source 其 setup.bash。当前 product/ 无 .cpp,该循环不生成任何目标。
file(GLOB PRODUCT_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_LIST_DIR}/product/*.cpp)
foreach(file ${PRODUCT_SOURCES})
  get_filename_component(filename ${file} NAME_WE)
  message(STATUS "add executable: ${filename}")
  add_executable(${filename} ${file})
  ament_target_dependencies(${filename} rclcpp interaction_msgs)
  install(TARGETS ${filename} DESTINATION lib/${PROJECT_NAME})
endforeach()

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  set(ament_cmake_cpplint_FOUND TRUE)
  set(ament_cmake_copyright_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
