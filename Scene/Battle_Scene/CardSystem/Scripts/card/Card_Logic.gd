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

# 保存当前 UI 对应的 RuntimeCard。
var runtime_card: RuntimeCard
# 保存当前卡牌 UI 状态。
var state: CardState = CardState.DRAWING
# 保存鼠标当前是否位于卡牌范围。
var is_hovered: bool = false
# 保留兼容属性并通过状态判断是否锁定。
var is_locked: bool:
	get:
		return state != CardState.IDLE

# 初始化组件并在第一帧渲染前隐藏卡牌。
func _ready() -> void:
	animation.setup(self, %Visuals)
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

# 根据 RuntimeCard 数据刷新所有文本表现。
func _update_visuals() -> void:
	if not runtime_card:
		return
	
	var type_value = runtime_card.base_data.get("card_type", 0)
	var is_attack: bool = type_value == 0
	
	name_label.text = tr(
		str(runtime_card.base_data.get("name", "未命名"))
	)
	
	description.text = tr(
		str(runtime_card.base_data.get("description", ""))
	)
	
	cost_label.text = str(runtime_card.get_resource_cost())
	animation.set_cost_color(cost_label, is_attack)

#region 交互触发
# 左键只发送出牌请求并等待上层确认。
func _on_left_clicked() -> void:
	if state != CardState.IDLE:
		return
	
	state = CardState.REQUESTING_PLAY
	interaction.set_enabled(false)
	
	card_played_request.emit(runtime_card)

# 右键只发送弃牌请求并等待上层确认。
func _on_right_clicked() -> void:
	if state != CardState.IDLE:
		return
	
	state = CardState.REQUESTING_DISCARD
	interaction.set_enabled(false)
	
	card_discarded_request.emit(runtime_card)

# 鼠标进入时开始播放 Visuals 悬浮动画。
func _on_hover_started() -> void:
	if state != CardState.IDLE:
		return
	
	is_hovered = true
	animation.play_hover_enter()

# 鼠标离开时恢复 Visuals 默认状态。
func _on_hover_ended() -> void:
	if state != CardState.IDLE:
		return
	
	is_hovered = false
	animation.play_hover_exit()
#endregion

# 上层确认出牌成功后才播放真正的出牌动画。
func confirm_play() -> void:
	if state != CardState.REQUESTING_PLAY:
		return
	
	state = CardState.EXITING
	animation.play_card_played()

# 上层确认弃牌成功后才播放真正的弃牌动画。
func confirm_discard() -> void:
	if state != CardState.REQUESTING_DISCARD:
		return
	
	state = CardState.EXITING
	animation.play_discard()

# 上层拒绝请求后恢复交互并播放错误反馈。
func reject_action() -> void:
	if state == CardState.IDLE or state == CardState.DRAWING:
		return
	
	animation.cancel_action_and_restore()
	
	state = CardState.IDLE
	interaction.set_enabled(true)
	
	is_hovered = get_global_rect().has_point(
		get_global_mouse_position()
	)
	
	animation.play_error_feedback()
	
	if is_hovered:
		animation.play_hover_enter()
	else:
		animation.play_hover_exit()

# 抽牌完成后进入正常交互状态。
func _on_draw_finished() -> void:
	if state != CardState.DRAWING:
		return
	
	state = CardState.IDLE
	interaction.set_enabled(true)
	
	is_hovered = get_global_rect().has_point(
		get_global_mouse_position()
	)
	
	if is_hovered:
		animation.play_hover_enter()

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
