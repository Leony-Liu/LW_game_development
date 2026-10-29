## 实例化卡牌场景并管理手牌区域的整体交互状态。
## 新卡会继承当前系统锁，避免抽牌动画结束后越过上层门闩。
extends HBoxContainer
class_name PlayerHandDeck

# 配置需要实例化的 Card 场景。
@export var card_scene: PackedScene

@export_category("Hand Layout")
@export var left_reserved_width: float = 440.0
@export var right_reserved_width: float = 340.0
@export var bottom_margin: float = 88.0

# 将出牌请求向上汇报
signal card_play_requested(runtime_card: RuntimeCard)
# 将弃牌请求向上汇报
signal card_discard_requested(runtime_card: RuntimeCard)
# 已确认出牌的卡牌视觉离场或被移除时回报完成。
signal card_play_exit_finished(runtime_card: RuntimeCard)
signal discard_mode_changed(active: bool)
signal card_hover_changed(runtime_card: RuntimeCard)

# 记录当前系统是否锁定了手牌交互
var is_input_locked: bool = false
var is_discard_mode_active: bool = false
var _playing_cards: Array[RuntimeCard] = []
var _hovered_card_ui: CardLogic = null


# 依据可用宽度居中现有手牌，并在卡牌数量或视口变化时重排。
func _ready() -> void:
	var canvas := get_parent() as Control
	if canvas == null:
		push_error("[PlayerHandDeck] 无法布局手牌：父节点不是 Control。")
		return
	canvas.resized.connect(_queue_hand_layout)
	child_entered_tree.connect(_queue_hand_layout.unbind(1))
	child_exiting_tree.connect(_queue_hand_layout.unbind(1))
	_queue_hand_layout()


# 等待容器完成增删卡牌，再计算实际最小宽度。
func _queue_hand_layout() -> void:
	_update_hand_layout.call_deferred()


# 在父级可编辑区域内缩放居中，卡牌仍由原 HBoxContainer 排列。
func _update_hand_layout() -> void:
	var canvas := get_parent() as Control
	if canvas == null or not is_inside_tree():
		return
	var card_width := 0.0
	var card_height := 280.0
	var card_count := 0
	for child in get_children():
		if child is Control and not child.is_queued_for_deletion():
			var card := child as Control
			card_width += card.get_combined_minimum_size().x
			card_height = maxf(card_height, card.get_combined_minimum_size().y)
			card_count += 1
	var natural_width := maxf(200.0, card_width + maxf(0.0, card_count - 1) * get_theme_constant("separation"))
	var left_space := minf(left_reserved_width, canvas.size.x * 0.23)
	var right_space := minf(right_reserved_width, canvas.size.x * 0.18)
	var available_width := maxf(1.0, canvas.size.x - left_space - right_space)
	var available_height := maxf(1.0, canvas.size.y - minf(bottom_margin, canvas.size.y * 0.08))
	var hand_scale := minf(1.0, minf(available_width / natural_width, available_height / card_height))
	size = Vector2(natural_width, card_height)
	scale = Vector2.ONE * hand_scale
	position = Vector2(left_space + (available_width - natural_width * hand_scale) * 0.5,
		canvas.size.y - minf(bottom_margin, canvas.size.y * 0.08) - card_height * hand_scale)

# 实例化 Card 并直接交给 HBoxContainer 自动排版。
func add_card_to_hand(runtime_card: RuntimeCard) -> CardLogic:
	if is_discard_mode_active:
		set_discard_mode(false)
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
	card_ui.hover_changed.connect(_on_card_hover_changed.bind(card_ui))
	card_ui.hovered_stats_updated.connect(_on_hovered_stats_updated.bind(card_ui))
	card_ui.exit_finished.connect(_on_card_exit_finished)
	card_ui.tree_exiting.connect(_on_card_exiting.bind(card_ui, runtime_card))
	
	card_ui.setup(runtime_card)
	
	# 新卡始终同步当前系统锁，锁状态会跨越抽牌动画保留。
	if card_ui.has_method("set_system_lock"):
		card_ui.set_system_lock(is_input_locked)
		
	return card_ui

# 接收 BattleManager 的 UI 锁定指令并下发给所有子卡牌。
func set_input_locked(locked: bool) -> void:
	if locked:
		_clear_hovered_card()
	if locked and is_discard_mode_active:
		set_discard_mode(false)
	is_input_locked = locked
	for child in get_children():
		if child is CardLogic and child.has_method("set_system_lock"):
			child.set_system_lock(locked)


# 模式由手牌视图持有，逐卡切换左键含义和弃牌提示。
func set_discard_mode(active: bool) -> bool:
	if active and is_input_locked:
		return false
	if is_discard_mode_active == active:
		return true
	is_discard_mode_active = active
	for child in get_children():
		if child is CardLogic:
			child.set_discard_mode(active)
	discard_mode_changed.emit(active)
	return true


# 清除旧战斗的卡牌节点，保留其他子节点与当前输入锁。
func clear_hand_visuals() -> void:
	_clear_hovered_card()
	set_discard_mode(false)
	for child in get_children():
		if child is CardLogic:
			remove_child(child)
			child.queue_free()

#region 向上汇报
# 只向上转发当前卡牌的悬停身份，忽略相邻卡牌迟到的离开事件。
func _on_card_hover_changed(runtime_card: RuntimeCard, hovered: bool, card_ui: CardLogic) -> void:
	if hovered:
		_hovered_card_ui = card_ui
		card_hover_changed.emit(runtime_card)
	elif card_ui == _hovered_card_ui:
		_clear_hovered_card()


# 运行时 Buff 改变当前卡的时间成本时重发预览请求。
func _on_hovered_stats_updated(runtime_card: RuntimeCard, card_ui: CardLogic) -> void:
	if card_ui == _hovered_card_ui:
		card_hover_changed.emit(runtime_card)


# 仅清除手牌视图保存的当前悬停身份。
func _clear_hovered_card() -> void:
	if _hovered_card_ui == null:
		return
	_hovered_card_ui = null
	card_hover_changed.emit(null)


# 弃牌模式取消后可读取仍处于悬停状态的卡牌。
func get_hovered_runtime_card() -> RuntimeCard:
	if is_instance_valid(_hovered_card_ui) and _hovered_card_ui.state == CardLogic.CardState.IDLE and _hovered_card_ui.is_hovered:
		return _hovered_card_ui.runtime_card
	return null


# 向上汇报出牌请求
func _on_card_played_request(runtime_card: RuntimeCard) -> void:
	card_play_requested.emit(runtime_card)

# 向上汇报弃牌请求
func _on_card_discarded_request(runtime_card: RuntimeCard) -> void:
	card_discard_requested.emit(runtime_card)
#endregion

#region 向下调用
# 上层确认出牌成功后找到对应 Card 并开始出牌动画。
func confirm_play(runtime_card: RuntimeCard) -> bool:
	var card_ui := _find_card(runtime_card)
	if not card_ui:
		return false
	
	if not card_ui.confirm_play():
		return false
	_playing_cards.append(runtime_card)
	return true

# 上层确认弃牌成功后找到对应 Card 并开始弃牌动画。
func confirm_discard(runtime_card: RuntimeCard) -> bool:
	var card_ui := _find_card(runtime_card)
	if not card_ui:
		return false
	
	return card_ui.confirm_discard()
#endregion

# 上层拒绝当前操作后找到 Card 并恢复交互。
func reject_action(runtime_card: RuntimeCard) -> void:
	var card_ui := _find_card(runtime_card)
	if not card_ui:
		return
	
	card_ui.reject_action()
	_finish_card_play_exit(runtime_card)

# 离场动画完成后由手牌容器负责删除自己的子节点。
func _on_card_exit_finished(runtime_card: RuntimeCard) -> void:
	_finish_card_play_exit(runtime_card)
	var card_ui := _find_card(runtime_card)
	if not card_ui:
		return
	
	card_ui.queue_free()


# 卡牌被提前移除时也结束相应的离场等待。
func _on_card_exiting(card_ui: CardLogic, runtime_card: RuntimeCard) -> void:
	if card_ui == _hovered_card_ui:
		_clear_hovered_card()
	if is_discard_mode_active:
		set_discard_mode(false)
	_finish_card_play_exit(runtime_card)


# 只为已确认出牌的卡牌发一次完成事件。
func _finish_card_play_exit(runtime_card: RuntimeCard) -> void:
	if not _playing_cards.has(runtime_card):
		return
	_playing_cards.erase(runtime_card)
	card_play_exit_finished.emit(runtime_card)

# 根据 RuntimeCard 引用寻找对应的 CardLogic。
func _find_card(runtime_card: RuntimeCard) -> CardLogic:
	for child in get_children():
		if child is CardLogic and child.runtime_card == runtime_card:
			return child
	
	return null
