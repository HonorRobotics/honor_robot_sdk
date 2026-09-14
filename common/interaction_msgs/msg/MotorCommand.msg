uint32 joint_id

# Command Mode: combination of each command bit
# 0x01 for pos, 0x02 for vel, 0x04 for tau, 0x08 for kp, 0x10 for kd
uint32 cmd_mode
uint32 CMD_MODE_DISABLE = 0x0
uint32 CMD_MODE_POS = 0x01
uint32 CMD_MODE_VEL = 0x02
uint32 CMD_MODE_TAU = 0x04
uint32 CMD_MODE_KP = 0x08
uint32 CMD_MODE_KD = 0x10

float32 pos # unit: rad
float32 vel # unit: rad/s
float32 tau # unit: Nm
float32 kp
float32 kd
