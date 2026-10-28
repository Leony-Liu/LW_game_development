## 为牌组提供原生单轴滚动及空白区域拖放目标。
## 只上报拖放意图，不执行容器操作。
extends ScrollContainer

signal card_dropped(data: Dictionary, destination_id: String)

@export_enum("combat_deck", "reserve_deck") var container_id: String = "combat_deck"
var session_id: int = 0

# 仅接收当前编辑会话中来自另一个牌组的卡牌身份。
func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "weapon_deck_card" and data.get("session_id") == session_id and data.get("source_id") in ["combat_deck", "reserve_deck"] and data.get("source_id") != container_id and data.get("card_uid") is String

# 拖放后由窗口通知拥有者，ScrollContainer 继续负责滚轮与滚动条。
func _drop_data(_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_position, data):
		card_dropped.emit(data, container_id)
