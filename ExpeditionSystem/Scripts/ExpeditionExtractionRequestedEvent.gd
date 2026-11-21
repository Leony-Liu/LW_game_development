## 远征已接受撤离请求时传递操作身份。
## 接受请求不表示撤离结算已经完成。
class_name ExpeditionExtractionRequestedEvent
extends RefCounted

var operation_id: int


# 保留 Manager 生成的原始操作 ID。
func _init(value: int) -> void:
	operation_id = value
