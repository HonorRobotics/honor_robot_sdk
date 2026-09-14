std_msgs/Header header      # 标准消息头，包含时间戳和帧ID
string device_name          # 设备名称

int16 imu_temperature       # 设备温度，单位摄氏度，实际温度 = imu_temperature / 10.0
int16 imu_frequency         # 频率，单位Hz
bool imu_status             # imu 是否正常工作

uint8 imu_data_type         # IMU数据流模式
uint8 DATA_UNKNOWN=0
uint8 DATA_QUATERNION=1
uint8 DATA_AHRS=2
