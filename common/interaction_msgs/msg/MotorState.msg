uint32 joint_id

uint32 mode # 0: Disable 1: Enable
float32 pos_fb # unit: rad
float32 vel_fb # unit: rad/s
float32 tau_fb # unit: Nm
float32[2] temp_fb # unit: °C; [0] T_MOS, [1] T_Rotor
uint32 error_code
