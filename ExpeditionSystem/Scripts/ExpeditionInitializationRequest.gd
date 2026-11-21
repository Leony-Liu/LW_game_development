## 远征初始化请求，只在同步调用期间借用玩家持有的来源武器。
## 接收方必须复制武器与容器，不得保留或修改此引用。
class_name ExpeditionInitializationRequest
extends RefCounted

var source_weapon: WeaponInstance


# 保存只读借用引用，实际复制由远征数据模型完成。
func _init(weapon: WeaponInstance) -> void:
	source_weapon = weapon
