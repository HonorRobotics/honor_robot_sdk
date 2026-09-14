std_msgs/Header header
float32 vx  # The unit is m/s. For example, 10.0 means 10 m/s. Interval(min, max) (0, 2.0)
float32 vy  # The unit is m/s. For example, 10.0 means 10 m/s. Interval(min, max) (0, 2.0)
float32 omega  # The unit is degree. For example, 10.0 means 10 degree. Interval(min, max) (-180.0, 180.0)
float32 duration  # The unit is second. For example, 10 means 10 seconds. Interval(min, max) (0, 5.0)

bool is_meta_action  # 'True' for use high level action api
