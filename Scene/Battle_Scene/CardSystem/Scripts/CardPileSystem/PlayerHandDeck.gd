extends Control

# 连接卡牌场景
@export var card_scene: PackedScene

# 使用数组存储5个槽位，方便通过索引快速访问
@onready var hand_slots: Array[Node] = [
	$Slot_1,
	$Slot_2,
	$Slot_3,
	$Slot_4,
	$Slot_5
]

func _ready() -> void:
	# 获取父节点 CardPileSystem
	var card_pile_system = get_parent() as CardPileSystem
	
	if card_pile_system:
		# 连接父节点的抽牌信号到本地的 _on_card_drawn 函数
		card_pile_system.card_drawn.connect(_on_card_drawn)
	else:
		push_error("PlayerHandDeck 的父节点不是 CardPileSystem")

# 接收父节点抽牌结果的槽函数
func _on_card_drawn(card_id: String, hand_pile_index: int) -> void:
	# 1. 安全检查：确保手牌索引不超过槽位数量 (最大为5)
	if hand_pile_index < 0 or hand_pile_index >= hand_slots.size():
		push_warning("手牌已满或索引越界，无法在UI中放置卡牌: " + str(hand_pile_index))
		return
		
	# 2. 安全检查：确保已经配置了卡牌的 UI 场景
	if not card_scene:
		push_error("尚未在 Inspector 中配置 card_scene！")
		return
		
	# 3. 实例化 Control 节点（视觉卡牌）
	var card_ui_instance = card_scene.instantiate()
	
	# 4. 根据 card_id 初始化 UI 数据 (假设你的UI脚本有一个 setup 或 init 方法)
	# if card_ui_instance.has_method("setup"):
	#     card_ui_instance.setup(card_id)
	
	# 5. 将实例化的卡牌添加到对应的槽位中
	var target_slot = hand_slots[hand_pile_index]
	target_slot.add_child(card_ui_instance)
	
	print("已在槽位 %s 实例化卡牌 ID: %s" % [target_slot.name, card_id])
