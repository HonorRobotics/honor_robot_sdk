std_msgs/Header header

uint32 version
uint32 tick

uint32 mode_machine
uint32 mode_pr
uint32 current_state_id
uint32 current_motion_id
uint32 last_state_id
uint32 last_motion_id
uint32 desired_state_id
uint32 desired_motion_id
float32 cycle_time
float32[3] pelvis_euler_zyx
float32[10] reserved

# Extended robot state (version >= 2)
uint32 action_id

# Quaternion component order: x, y, z, w
float32[4] pelvis_quaternion_xyzw

float32[3] cmd_base_position
float32[3] cmd_base_euler_zyx
float32[3] cmd_base_linear_velocity
float32[3] cmd_base_angular_velocity

float32[3] raw_cmd_base_linear_velocity
float32[3] raw_cmd_base_angular_velocity
float32[3] est_base_linear_velocity
float32[3] est_base_angular_velocity

bool motor_enabled
bool is_sim
uint32 status_flags

# Logical forward direction along the base-frame X axis.
# +X and -X may be swapped for a head-tail symmetric robot.
int8 FORWARD_DIRECTION_UNKNOWN=0
int8 FORWARD_DIRECTION_POSITIVE_X=1
int8 FORWARD_DIRECTION_NEGATIVE_X=-1
int8 forward_direction
