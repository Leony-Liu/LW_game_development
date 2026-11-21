## 向远征提交对应撤离操作的拒绝原因。
## 操作身份由 Manager 校验，过期请求不可改变终局状态。
class_name ExpeditionExtractionRejectionRequest
extends RefCounted

var operation_id: int
var reason: String


# 将操作 ID 与原因作为同一请求传递。
func _init(id: int, rejection_reason: String) -> void:
	operation_id = id
	reason = rejection_reason
