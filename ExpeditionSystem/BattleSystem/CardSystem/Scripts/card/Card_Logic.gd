## 管理单张卡牌的展示、交互状态与请求生命周期。
## 系统锁独立于动画状态保存，动画完成不能擅自恢复交互。
extends Control
class_name CardLogic

# 定义卡牌 UI 当前所处的交互状态。
enum CardState {
	DRAWING,
	IDLE,
	REQUESTING_PLAY,
	REQUESTING_DISCARD,
	EXITING
}

#region 节点引用
# 保存费用文本节点。
@export var cost_label: Label
# 保存名称文本节点。
@export var name_label: Label
# 保存描述文本节点。
@export var description: Label
# 可选类型文本；旧场景未绑定时仍保留费用颜色提示。
@export var type_label: Label
# 静态展示复用卡面，不启用战斗输入或抽牌动画。
@export var presentation_only: bool = false
# 保存输入组件。
@export var interaction: Node
# 保存动画组件。
@export var animation: Node
#endregion

# 请求上层判断当前卡牌能否出牌。
signal card_played_request(runtime_card: RuntimeCard)
# 请求上层判断当前卡牌能否弃牌。
signal card_discarded_request(runtime_card: RuntimeCard)
# 卡牌离场动画完成后通知手牌容器删除节点。
signal exit_finished(runtime_card: RuntimeCard)
signal hover_changed(runtime_card: RuntimeCard, hovered: bool)
signal hovered_stats_updated(runtime_card: RuntimeCard)

# 保存当前 UI 对应的 RuntimeCard。
var runtime_card: RuntimeCard
# 保存当前卡牌 UI 状态。
var state: CardState = CardState.DRAWING
# 保存鼠标当前是否位于卡牌范围。
var is_hovered: bool = false
var _is_system_locked: bool = false
var _discard_mode_active: bool = false
# 保留兼容属性并通过状态判断是否锁定。
var is_locked: bool:
	get:
		return state != CardState.IDLE

# 初始化组件并在第一帧渲染前隐藏卡牌。
func _ready() -> void:
	animation.setup(self, %Visuals)
	if presentation_only:
		return
	animation.prepare_draw()
	
	interaction.setup(self)
	interaction.set_enabled(false)
	
	interaction.hover_started.connect(_on_hover_started)
	interaction.hover_ended.connect(_on_hover_ended)
	interaction.left_clicked.connect(_on_left_clicked)
	interaction.right_clicked.connect(_on_right_clicked)
	
	animation.draw_finished.connect(_on_draw_finished)
	animation.exit_finished.connect(_on_exit_animation_finished)

# 注入 RuntimeCard 并在布局完成后播放抽牌动画。
func setup(in_runtime_card: RuntimeCard) -> void:
	runtime_card = in_runtime_card
	
	runtime_card.stats_updated.connect(_update_visuals)
	_update_visuals()
	
	# 等待 HBoxContainer 完成 Card 的最终尺寸和排版。
	await get_tree().process_frame
	
	if not is_instance_valid(self):
		return
	
	animation.initialize_transform()
	animation.play_draw()

# 直接展示持久实例的模板，不创建 RuntimeCard 或改写实例数据。
func display_instance(card: CardInstance) -> void:
	if not presentation_only:
		push_error("[CardLogic] 静态展示失败：必须启用 presentation_only。")
		return
	if card.card_data == null:
		name_label.text = "模板不可用（ID %d）" % card.card_id
		description.text = ""
		cost_label.text = ""
		if type_label != null:
			type_label.text = ""
		return
	var data := card.card_data
	var cost := data.stamina_cost if data.card_type == CardData.CardType.Attack else data.mana_cost
	_display_data(data.name, data.description, cost, data.card_type)

# 共用模板上的文本和费用颜色，不参与牌组或战斗状态计算。
func _display_data(card_name: String, card_description: String, cost: int, card_type: int) -> void:
	name_label.text = tr(card_name)
	description.text = tr(card_description)
	cost_label.text = str(cost)
	if type_label != null:
		type_label.text = CardData.CardType.find_key(card_type)
	animation.set_cost_color(cost_label, card_type == CardData.CardType.Attack)

# 根据 RuntimeCard 数据刷新所有文本表现。
func _update_visuals() -> void:
	if not runtime_card:
		return
	
	_display_data(
		str(runtime_card.card_data.get("name", "未命名")),
		str(runtime_card.card_data.get("description", "")),
		runtime_card.get_resource_cost(),
		int(runtime_card.card_data.get("card_type", 0))
	)
	if is_hovered and state == CardState.IDLE:
		hovered_stats_updated.emit(runtime_card)

#region 交互触发
# 左键按当前手牌模式发送请求并等待上层确认。
func _on_left_clicked() -> void:
	if state != CardState.IDLE:
		return
	if _discard_mode_active:
		_on_right_clicked()
		return
	state = CardState.REQUESTING_PLAY
	_clear_hover_for_action()
	interaction.set_enabled(false)
	
	card_played_request.emit(runtime_card)

# 右键只发送弃牌请求并等待上层确认。
func _on_right_clicked() -> void:
	if state != CardState.IDLE:
		return
	
	state = CardState.REQUESTING_DISCARD
	_clear_hover_for_action()
	interaction.set_enabled(false)
	
	card_discarded_request.emit(runtime_card)

# 鼠标进入时开始播放 Visuals 悬浮动画。
func _on_hover_started() -> void:
	if state != CardState.IDLE:
		return
	
	is_hovered = true
	animation.play_hover_enter()
	hover_changed.emit(runtime_card, true)
	if _discard_mode_active:
		animation.set_discard_target(true)

# 鼠标离开时恢复 Visuals 默认状态。
func _on_hover_ended() -> void:
	if state != CardState.IDLE:
		return
	
	is_hovered = false
	animation.set_discard_target(false)
	animation.play_hover_exit()
	hover_changed.emit(runtime_card, false)


# 卡牌进入操作流程时立即撤销悬停预览。
func _clear_hover_for_action() -> void:
	if is_hovered:
		is_hovered = false
		hover_changed.emit(runtime_card, false)
#endregion

#region 动画触发
# 上层确认出牌成功后才播放出牌动画。
func confirm_play() -> bool:
	if state != CardState.REQUESTING_PLAY:
		return false
	
	if not animation.play_card_played():
		return false
	state = CardState.EXITING
	return true

# 上层确认弃牌成功后才播放弃牌动画。
func confirm_discard() -> bool:
	if state != CardState.REQUESTING_DISCARD:
		return false
	
	state = CardState.EXITING
	animation.set_discard_target(false)
	animation.play_discard()
	return true

# 上层拒绝请求后恢复交互并播放错误反馈。
func reject_action() -> void:
	if state != CardState.REQUESTING_PLAY and state != CardState.REQUESTING_DISCARD:
		return
	
	animation.cancel_action_and_restore()
	
	state = CardState.IDLE
	interaction.set_enabled(not _is_system_locked)
	
	is_hovered = get_global_rect().has_point(
		get_global_mouse_position()
	)
	
	if _discard_mode_active:
		animation.set_discard_target(is_hovered)
	else:
		animation.play_error_feedback()
	
	if is_hovered:
		animation.play_hover_enter()
		if _discard_mode_active:
			animation.set_discard_target(true)
		hover_changed.emit(runtime_card, true)
	else:
		animation.play_hover_exit()

# 抽牌完成后进入正常交互状态。
func _on_draw_finished() -> void:
	if state != CardState.DRAWING:
		return
	
	state = CardState.IDLE
	interaction.set_enabled(not _is_system_locked)
	
	is_hovered = get_global_rect().has_point(
		get_global_mouse_position()
	)
	
	if is_hovered:
		animation.play_hover_enter()
		hover_changed.emit(runtime_card, true)

# 离场动画完成后通知 PlayerHandDeck 删除卡牌。
func _on_exit_animation_finished() -> void:
	if state != CardState.EXITING:
		return
	
	exit_finished.emit(runtime_card)

# Hover 状态下使用 Card 本地坐标计算鼠标旋转。
func _process(delta: float) -> void:
	if state != CardState.IDLE or not is_hovered:
		return
	
	if size.x <= 0.0:
		return
	
	var local_mouse_x := get_local_mouse_position().x
	var offset_x := local_mouse_x - size.x * 0.5
	
	animation.update_dynamic_rotation(
		delta,
		offset_x,
		size.x
	)
#endregion

# 接收系统锁并保留状态，避免动画结束时错误解锁。
func set_system_lock(locked: bool) -> void:
	_is_system_locked = locked
	if locked and is_hovered:
		is_hovered = false
		hover_changed.emit(runtime_card, false)
	if state == CardState.IDLE:
		interaction.set_enabled(not locked)


# 手牌视图下发模式时只切换本卡的显示与左键含义。
func set_discard_mode(active: bool) -> void:
	_discard_mode_active = active
	animation.set_discard_target(active and state == CardState.IDLE and is_hovered)
