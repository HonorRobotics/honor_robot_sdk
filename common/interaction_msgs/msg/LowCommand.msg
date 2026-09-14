std_msgs/Header header

uint32 mode_pr # Parallel Joint Mode: 0 for PR mode, 1 for raw motor mode
uint32 MODE_PR = 0
uint32 MODE_RAW = 1

uint32 mode_machine
uint32 MACHINE_NORMAL = 0

MotorCommand[] motor_cmd
