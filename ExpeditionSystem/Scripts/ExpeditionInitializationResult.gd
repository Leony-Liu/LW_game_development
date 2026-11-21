## 表达一次同步远征初始化的明确结果。
## 不持有远征内部节点或玩家数据引用。
class_name ExpeditionInitializationResult
extends RefCounted

var succeeded: bool


# 仅在 Manager 完成初始化后标记成功。
func _init(value: bool) -> void:
	succeeded = value
