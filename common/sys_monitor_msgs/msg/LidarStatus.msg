# LidarStatus message data
std_msgs/Header header      # 标准消息头，包含时间戳和帧ID
string device_name          # 设备名称

bool  switch_status         # LiDAR on/off status (true: on, false: off)
uint8 imu_frequency         # [hz] IMU frequency
uint8 lidar_frequency       # [hz] lidar frequency
int16 lidar_temperature     # [°C] Lidar temperature information, actual temperature = lidar_temperature / 100.0