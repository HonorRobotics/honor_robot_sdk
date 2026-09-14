cmake_minimum_required(VERSION 3.12)

project(common)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_CXX_FLAGS "-std=c++17 -fPIC")
set(CMAKE_C_FLAGS "-std=c17 -fPIC")
set(CMAKE_BUILD_TYPE "RelWithDebInfo")

add_subdirectory(interaction_msgs)
add_subdirectory(robot_msgs)
add_subdirectory(camera_msgs)
add_subdirectory(sys_monitor_msgs)
