# 导航/规划状态反馈(仅用 /goal_pose 设目标时,替代 Action feedback)

# 规划状态
uint8 IDLE      = 0   # 空闲,无目标
uint8 PLANNING  = 1   # 规划中(已设目标,尚未搜到路径)
uint8 FOLLOWING = 2   # 已规划出路径,跟踪执行中
uint8 REACHED   = 3   # 已到达终点
uint8 FAILED    = 4   # 规划失败(看 error_code)

# 规划失败原因(error_code,status == FAILED 时有效)
uint8 NONE            = 0   # 无错误
uint8 NO_VALID_GRAPH  = 1   # 路网图不存在/加载失败
uint8 GOAL_TOO_FAR    = 2   # 目标点距离路网过远
uint8 DEAD_END_GOAL   = 3   # 终点节点无出边(单链末端)
uint8 NO_ROUTE        = 4   # 起终点之间搜不到可达路径
uint8 UNKNOWN         = 5   # 未知错误

uint8 status
uint8 error_code
uint32 next_node_id   # 路网规划时当前下一节点 id
