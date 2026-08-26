extends Control
class_name PlayerHandDeck

# 绑定单张卡牌节点
@export var card_scene: PackedScene

# 向上汇报信号
signal card_play_requested(hand_pile_index: int)
signal card_discard_requested(hand_pile_index: int)

# 使用数组存储5个槽位，方便通过索引快速访问
@onready var hand_slots: Array[Node] = [
	$Slot_1,
	$Slot_2,
	$Slot_3,
	$Slot_4,
	$Slot_5
]

# 实例化卡牌
func add_card_to_hand(card_id: String, hand_pile_index: int) -> void:
	# 1. 检查：确保手牌索引不超过槽位数量
	if hand_pile_index < 0 or hand_pile_index >= hand_slots.size():
		push_warning("手牌已满或索引越界，无法在UI中放置卡牌: " + str(hand_pile_index))
		return
		
	# 2. 检查：确保已经配置了卡牌的 UI 场景
	if not card_scene:
		push_error("尚未在 Inspector 中配置 card_scene！")
		return
		
	# 3. 实例化 Control 节点（视觉卡牌）
	var card_ui_instance = card_scene.instantiate()
	
	# 4. 接收下级信号，用于后续向上汇报
	card_ui_instance.card_played_request.connect(_on_card_played_request)
	card_ui_instance.card_discarded_request.connect(_on_card_discarded_request)
	
	# 5. 初始化卡牌数据，将String的ID转为int以适应
	if card_ui_instance.has_method("setup"):
		card_ui_instance.setup(card_id.to_int(), hand_pile_index)
	
	# 6. 将实例化的卡牌添加到对应的槽位中
	var target_slot = hand_slots[hand_pile_index]
	target_slot.add_child(card_ui_instance)
	
	print("已在槽位 %s 实例化卡牌 ID: %s" % [target_slot.name, card_id])

#region 汇报信号
# 处理CL发来的出牌请求信号，继续向上传递给CPS
func _on_card_played_request(_card_id: int, card_slot: int) -> void:
	card_play_requested.emit(card_slot)

# 处理下级CL发来的弃牌请求信号，继续向上传递给CPS
func _on_card_discarded_request(_card_id: int, card_slot: int) -> void:
#endregion
	card_discard_requested.emit(card_slot)
