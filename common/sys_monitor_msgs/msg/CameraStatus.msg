std_msgs/Header header      # 标准消息头，包含时间戳和帧ID
string device_name          # 设备名称

# RGB 摄像头
int16 rgb_temperature         # RGB 设备温度，单位摄氏度，实际温度 = rgb_temperature / 10.0
uint8 rgb_frequency           # RGB 频率，单位Hz
bool rgb_switch_status        # RGB 是否起流，true表示起流，false表示未起流
int16 rgb_resolution_width    # RGB 分辨率宽度
int16 rgb_resolution_height   # RGB 分辨率高度

# LDP (激光点投影器)
int16 ldp_temperature         # LDP 设备温度，单位摄氏度，实际温度 = ldp_temperature / 10.0
bool ldp_switch_status        # LDP 是否起流，true表示起流，false表示未起流
uint8 ldp_energy_level        # LDP 能级

# IR 红外摄像头
int16 ir_left_temperature     # 左侧 IR 温度，单位摄氏度，实际温度 = ir_left_temperature / 10.0
int16 ir_right_temperature    # 右侧 IR 温度，单位摄氏度，实际温度 = ir_right_temperature / 10.0
uint8 ir_frame_rate           # IR 帧率，单位Hz
bool ir_switch_status         # IR 是否起流，true表示起流，false表示未起流
int16 ir_resolution_width     # IR 分辨率宽度
int16 ir_resolution_height    # IR 分辨率高度

# IMU 传感器
bool imu_switch_status        # IMU 是否起流，true表示起流，false表示未起流
int16 imu_temperature         # IMU 温度，单位摄氏度，实际温度 = imu_temperature / 10.0
uint8 imu_frequency           # IMU 频率，单位Hz

# CPU
int16 cpu_temperature         # CPU 温度，单位摄氏度，实际温度 = cpu_temperature / 10.0
