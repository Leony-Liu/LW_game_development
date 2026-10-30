## 承载现有 Card.tscn，提供牌组拖拽与右键意图。
## 只适配输入和等比缩放，不创建卡面或修改卡牌实例。
extends Control

signal transfer_requested(container_id: String, uid: String)
signal card_dropped(data: Dictionary, destination_id: String)

var container_id: String
var card_uid: String
var session_id: int
var _display_name: String
var _interaction_enabled: bool = true

# 仅切换本实例的编辑操作，保留 PASS 输入和原生滚轮传播。
func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled

# 卡面不接收输入，由本适配层唯一处理牌组操作。
func _ready() -> void:
	_ignore_card_input(%CardView)

# 子控件不截获右键、拖拽或滚轮，保留卡面原有布局。
func _ignore_card_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_card_input(child)

# 使用模板原尺寸统一缩放，容器只排列占位尺寸。
func set_card_scale(value: float) -> void:
	var template_size: Vector2 = %CardView.custom_minimum_size
	custom_minimum_size = template_size * value
	%CardView.size = template_size
	%CardView.scale = Vector2.ONE * value

# 只读渲染已有模板；缺失模板显示诊断，不伪造卡牌内容。
func display_card(card: CardInstance, source_id: String, session: int) -> void:
	container_id = source_id
	card_uid = card.unique_id
	session_id = session
	%CardView.display_instance(card)
	_display_name = %CardView.name_label.text
	tooltip_text = %CardView.description.text

# 右键只通知当前容器和实例身份。
func _gui_input(event: InputEvent) -> void:
	if _interaction_enabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		transfer_requested.emit(container_id, card_uid)

# 原生左键拖拽只携带身份；预览采用已有名称。
func _get_drag_data(_position: Vector2) -> Variant:
	if not _interaction_enabled:
		return null
	var preview := Label.new()
	preview.text = _display_name
	preview.custom_minimum_size = Vector2(160, 50)
	set_drag_preview(preview)
	return {"kind": "weapon_deck_card", "session_id": session_id, "source_id": container_id, "card_uid": card_uid}

# 卡片区域也接受来自另一容器的拖放，行为与空白区域一致。
func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return _interaction_enabled and data is Dictionary and data.get("kind") == "weapon_deck_card" and data.get("session_id") == session_id and data.get("source_id") in ["combat_deck", "reserve_deck"] and data.get("source_id") != container_id and data.get("card_uid") is String

# 上报拖放目标，交由窗口与 Base 再校验。
func _drop_data(_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_position, data):
		card_dropped.emit(data, container_id)
