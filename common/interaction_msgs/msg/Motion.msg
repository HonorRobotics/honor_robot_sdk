std_msgs/Header header

# MotionType enum definition
uint32 motion
uint32 MOTION_SQUAT = 0
uint32 MOTION_SIT = 1
uint32 MOTION_STANDUP = 2
uint32 MOTION_STOPMOVE = 3
uint32 MOTION_HIGHSTAND = 4
uint32 MOTION_LOWSTAND = 5
uint32 MOTION_BALANCESTAND = 6

bool is_meta_action  # 'True' for use high level action api​
