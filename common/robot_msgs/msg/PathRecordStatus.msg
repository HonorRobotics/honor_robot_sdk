# 路径录制状态反馈

# 录制总体状态
uint8 IDLE      = 0   # 未录制
uint8 RECORDING = 1   # 录制中
uint8 SAVING    = 2   # 结束落盘中
uint8 DONE      = 3   # 录制成功(已落盘)
uint8 FAILED    = 4   # 录制失败(看 error_code)

# 失败原因(error_code)
uint8 NONE              = 0   # 无错误
uint8 LOCALIZATION_LOST = 1   # 定位丢失(长时间无里程计更新)
uint8 LOCALIZATION_JUMP = 2   # 定位跳变(相邻采样点距离突变)
uint8 PATH_TOO_SHORT    = 3   # 录制总距离过短(低于阈值)
uint8 PATH_EMPTY        = 4   # 录制轨迹为空
uint8 WRITE_FAILED      = 5   # 文件写入失败(磁盘满/权限等)
uint8 TIMEOUT           = 6   # 录制超时

uint8 status
uint8 error_code
uint32 count          # 当前已保存的路径条数(0..max_count)
