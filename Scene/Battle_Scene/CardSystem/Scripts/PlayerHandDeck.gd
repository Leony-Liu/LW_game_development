# 实例化卡牌场景、信号交接
extends HBoxContainer
class_name PlayerHandDeck

# 配置需要实例化的 Card 场景。
@export var card_scene: PackedScene

# 将出牌请求向上汇报
signal card_play_requested(runtime_card: RuntimeCard)
# 将弃牌请求向上汇报
signal card_discard_requested(runtime_card: RuntimeCard)


# 实例化 Card 并直接交给 HBoxContainer 自动排版。
func add_card_to_hand(runtime_card: RuntimeCard) -> CardLogic:
	if not card_scene:
		push_error("未配置 card_scene！")
		return null
	
	var card_ui := card_scene.instantiate() as CardLogic
	if not card_ui:
		push_error("card_scene 根节点必须使用 CardLogic。")
		return null
	
	# add_child 后 Card 自动成为 HBoxContainer 的排版对象。
	add_child(card_ui)
	
	card_ui.card_played_request.connect(_on_card_played_request)
	card_ui.card_discarded_request.connect(_on_card_discarded_request)
	card_ui.exit_finished.connect(_on_card_exit_finished)
	
	card_ui.setup(runtime_card)
	
	return card_ui

# 收到 Card 的请求后只负责继续汇报给战斗逻辑。
func _on_card_played_request(runtime_card: RuntimeCard) -> void:
	card_play_requested.emit(runtime_card)

# 收到 Card 的弃牌请求后只负责继续汇报给战斗逻辑。
func _on_card_discarded_request(runtime_card: RuntimeCard) -> void:
	card_discard_requested.emit(runtime_card)

# 上层确认出牌成功后找到对应 Card 并开始出牌动画。
func confirm_play(runtime_card: RuntimeCard) -> void:
	var card_ui := _find_card(runtime_card)
	if not card_ui:
		return
	
	card_ui.confirm_play()

# 上层确认弃牌成功后找到对应 Card 并开始弃牌动画。
func confirm_discard(runtime_card: RuntimeCard) -> void:
	var card_ui := _find_card(runtime_card)
	if not card_ui:
		return
	
	card_ui.confirm_discard()

# 上层拒绝当前操作后找到 Card 并恢复交互。
func reject_action(runtime_card: RuntimeCard) -> void:
	var card_ui := _find_card(runtime_card)
	if not card_ui:
		return
	
	card_ui.reject_action()

# 离场动画完成后由手牌容器负责删除自己的子节点。
func _on_card_exit_finished(runtime_card: RuntimeCard) -> void:
	var card_ui := _find_card(runtime_card)
	if not card_ui:
		return
	
	card_ui.queue_free()

# 根据 RuntimeCard 引用寻找对应的 CardLogic。
func _find_card(runtime_card: RuntimeCard) -> CardLogic:
	for child in get_children():
		if child is CardLogic and child.runtime_card == runtime_card:
			return child
	
	return null
