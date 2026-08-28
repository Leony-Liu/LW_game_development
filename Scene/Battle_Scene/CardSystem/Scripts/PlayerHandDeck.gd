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

# 实例化卡牌：参数改为接收 RuntimeCard 实例
func add_card_to_hand(runtime_card: RuntimeCard, hand_pile_index: int) -> void:
	if hand_pile_index < 0 or hand_pile_index >= hand_slots.size():
		return push_warning("手牌已满或索引越界")
		
	if not card_scene:
		return push_error("未配置 card_scene！")
		
	var card_ui_instance = card_scene.instantiate()
	card_ui_instance.card_played_request.connect(_on_card_played_request)
	card_ui_instance.card_discarded_request.connect(_on_card_discarded_request)
	
	# 向下级 UI 注入 RuntimeCard 实例
	if card_ui_instance.has_method("setup"):
		card_ui_instance.setup(runtime_card, hand_pile_index)
	
	var target_slot = hand_slots[hand_pile_index]
	target_slot.add_child(card_ui_instance)


#region 向上汇报信号
# 处理CL发来的出牌请求信号，继续向上传递给CPS
func _on_card_played_request(runtime_card: RuntimeCard, card_slot: int) -> void:
	card_play_requested.emit(card_slot)

# 处理下级CL发来的弃牌请求信号，继续向上传递给CPS
func _on_card_discarded_request(runtime_card: RuntimeCard, card_slot: int) -> void:
	card_discard_requested.emit(card_slot)
#endregion
