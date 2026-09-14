std_msgs/Header header

# Raw interpolated 24-body SMPL/XRT poses before deploy conversion, row-major
# (24 * 7). Per-body layout: position xyz followed by quaternion xyzw, in the
# source XRT/Unity frame.
float32[168] smpl_body_poses

# SMPL 24-joint local positions (pre-baked y2z + remove-base), row-major (24 * 3).
float32[78] smpl_joints_local

# SMPL root quaternion in motion-local frame, wxyz.
float32[4]  smpl_root_quat

# SMPL root pos in world frame.
float32[3]  smpl_root_pos

# Diagnostics: current motion frame index (post-resample). Wraps per clip.
uint32 frame_index

# Monotonic motion-time of this frame on the sender's clock (nanoseconds). The
# downstream resamples this variable-rate stream onto its fixed 50 Hz policy
# grid by interpolating on this timeline, decoupling publish rate from inference
# rate. Monotonic within a stream_epoch.
uint64 motion_time_ns

# Bumped by the sender on any timeline discontinuity (source reconnect, clip
# switch / wrap, manual retarget reset). The consumer re-anchors its playback
# cursor when this changes instead of interpolating across the gap.
uint32 stream_epoch

# Retargeted robot targets, carried here so the downstream reads the wrist DoFs
# from robot_joint_pos (the redundant wrist field is gone) and a robot-reference
# policy can consume the full pose from the resampled MotionRef stream. Natural
# 29-DoF order; its 6 wrist slots hold the SMPL-derived pre-retarget wrist (not
# the retargeter's wrist output). root quat wxyz; root pos xyz in the integrated
# world frame (retargeter planar velocity + absolute height).
float32[29] robot_joint_pos
float32[4]  robot_root_quat
float32[3]  robot_root_pos

# Retargeted head target, natural order [yaw, pitch] (head_num_dofs = 2). Driven
# through the same resampled stream as the body so RL_WBC can PD-track the head
# to the operator; held/blended by the consumer across PAUSE <-> RESUME edges.
float32[2]  head_pos

# Optional gripper or dexterous-hand command, already encoded for hand output.
# FingerCommand.manufacturer is authoritative: 2=dexterous hand, 3=gripper.
# Leave dexhand_cmd empty when this frame does not carry a hand command.
DexhandCmd hand_pos

# Deprecated compatibility field. RL_WBC ignores it and uses manufacturer.
bool hand_pos_from_gripper

# Request the perception-capable policy to use depth input. The controller may
# force this false when the loaded policy does not support perception or depth
# data is not available yet.
bool use_depth
