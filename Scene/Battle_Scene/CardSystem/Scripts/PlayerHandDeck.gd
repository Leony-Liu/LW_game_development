extends Control
class_name PlayerHandDeck

# 绑定单张卡牌场景
@export var card_scene: PackedScene
# 卡牌之间的间隔宽度（可在编辑器中调整）
@export var card_spacing: float

signal card_play_requested(runtime_card: RuntimeCard)
signal card_discard_requested(runtime_card: RuntimeCard)

# 实例化单张卡牌到手牌处
func add_card_to_hand(runtime_card: RuntimeCard) -> void:
	if not card_scene: return push_error("未配置 card_scene！")
		
	var card_ui = card_scene.instantiate()
	card_ui.card_played_request.connect(_on_card_played_request)
	card_ui.card_discarded_request.connect(_on_card_discarded_request)
	
	add_child(card_ui)
	if card_ui.has_method("setup"):
		card_ui.setup(runtime_card)
		
	# 新卡加入后，立刻重新计算所有卡牌的位置
	_rearrange_cards()

# 核心重排算法：让手牌永远居中对齐，并平滑移动
func _rearrange_cards() -> void:
	var valid_cards = []
	# 筛选出所有有效卡牌（排除掉那些正在播放出牌/弃牌销毁动画的卡牌）
	for child in get_children():
		if child is CardLogic and not child.is_locked:
			valid_cards.append(child)
			
	var count = valid_cards.size()
	if count == 0: return
	
	# 计算整个牌列的总宽度，以得出第一张牌的起始 X 坐标，实现整体居中
	var total_width = (count - 1) * card_spacing
	var start_x = (size.x - total_width) / 2.0
	var center_y = size.y / 2.0
	
	for i in range(count):
		var card = valid_cards[i]
		var target_pos = Vector2(start_x + i * card_spacing, center_y)
		# 使用补间动画让卡牌平滑滑动到新位置
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position", target_pos, 0.25)

#region 向上汇报信号
func _on_card_played_request(runtime_card: RuntimeCard) -> void:
	# 某张牌被打出时（已被设为锁定），立刻触发重排，剩下的牌会自动往中间靠拢
	_rearrange_cards() 
	card_play_requested.emit(runtime_card)

func _on_card_discarded_request(runtime_card: RuntimeCard) -> void:
	_rearrange_cards()
	card_discard_requested.emit(runtime_card)
#endregion
