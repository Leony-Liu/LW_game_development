extends Node

# 抽牌动画完成后通知 CardLogic 开启交互。
signal draw_finished
# 出牌或弃牌动画完成后通知 CardLogic。
signal exit_finished


#region 动画效果配置
@export_category("UI Colors")
# 配置攻击牌费用颜色。
@export var attack_cost_color: Color = Color("1db847")
# 配置技能牌费用颜色。
@export var skill_cost_color: Color = Color("00bfff")


@export_category("Hover Animation")
# 配置悬浮时的缩放倍率。
@export var hover_scale: float = 1.1
# 配置悬浮时向上的移动距离。
@export var hover_lift: float = 20.0
# 配置悬浮时的最大旋转角度。
@export var max_rotation: float = 5.0
# 配置鼠标旋转跟随速度。
@export var rotation_follow_speed: float = 10.0
# 配置悬浮进入动画时间。
@export var hover_enter_duration: float = 0.10
# 配置悬浮退出动画时间。
@export var hover_exit_duration: float = 0.15
# 配置悬浮时使用的显示层级。
@export var hover_z_index: int = 100


@export_category("Draw Animation")
# 配置抽牌动画持续时间。
@export var draw_duration: float = 0.20
# 配置抽牌时从下方进入的距离。
@export var draw_y_offset: float = 30.0


@export_category("Play Animation")
# 配置出牌动画持续时间。
@export var play_duration: float = 0.20
# 配置出牌时向上的飞行距离。
@export var play_y_offset: float = 100.0
# 配置出牌时的放大倍率。
@export var play_scale: float = 1.15


@export_category("Discard Animation")
# 配置弃牌动画持续时间。
@export var discard_duration: float = 0.18
# 配置弃牌时向下掉落的距离。
@export var discard_y_offset: float = 80.0
# 配置弃牌时的缩放倍率。
@export var discard_scale: float = 0.85
# 配置弃牌时的旋转角度。
@export var discard_rotation: float = 10.0
#endregion


#region 变量初始化
# 保存 Card 根节点并只修改非布局属性。
var card: Control
# 保存所有视觉动画唯一允许修改的节点。
var visual_root: Control
# 保存 Visuals 的默认局部位置。
var original_visual_position: Vector2
# 保存 Visuals 的默认缩放。
var original_visual_scale: Vector2
# 保存 Visuals 的默认旋转。
var original_visual_rotation: float
# 保存 Visuals 的默认颜色。
var original_visual_modulate: Color
# 保存 Card 的默认颜色。
var original_card_modulate: Color
# 保存 Card 的默认显示层级。
var original_z_index: int
# 保存 Card 的默认鼠标过滤状态。
var original_mouse_filter: int
# 标记 Visuals 的布局数据是否已经缓存。
var is_transform_initialized: bool = false

# 管理悬浮动画并避免多个 Hover Tween 冲突。
var hover_tween: Tween
# 管理抽牌动画并避免和其他视觉位移冲突。
var draw_tween: Tween
# 管理出牌和弃牌动画。
var action_tween: Tween
# 管理操作失败时的颜色反馈。
var feedback_tween: Tween
#endregion


# 保存 Card 和 Visuals 引用并记录不会变化的基础属性。
func setup(p_card: Control, p_visual_root: Control) -> void:
	card = p_card
	visual_root = p_visual_root
	
	original_card_modulate = card.modulate
	original_visual_modulate = visual_root.modulate
	original_z_index = card.z_index
	original_mouse_filter = card.mouse_filter

# 在第一帧渲染前隐藏 Card 防止抽牌动画闪现。
func prepare_draw() -> void:
	if not is_instance_valid(card):
		return
	
	var hidden_color := original_card_modulate
	hidden_color.a = 0.0
	card.modulate = hidden_color

# 布局完成后缓存 Visuals 的位置并设置动画中心。
func initialize_transform() -> void:
	if is_transform_initialized:
		return
	
	if not is_instance_valid(card) or not is_instance_valid(visual_root):
		push_error("Card 或 Visuals 节点丢失。")
		return
	
	visual_root.pivot_offset = visual_root.size * 0.5
	original_visual_position = visual_root.position
	original_visual_scale = visual_root.scale
	original_visual_rotation = visual_root.rotation_degrees
	
	is_transform_initialized = true

# 根据卡牌类型设置费用文字颜色。
func set_cost_color(label: Label, is_attack: bool) -> void:
	var target_color := attack_cost_color if is_attack else skill_cost_color
	label.add_theme_color_override("font_color", target_color)

# 根据鼠标横向位置平滑旋转 Visuals。
func update_dynamic_rotation(delta: float, offset_x: float, card_width: float) -> void:
	if not is_transform_initialized or card_width <= 0.0:
		return
	
	var half_width := card_width * 0.5
	var normalized_offset := clampf(offset_x / half_width, -1.0, 1.0)
	var target_rotation := original_visual_rotation + normalized_offset * max_rotation
	var weight := clampf(rotation_follow_speed * delta, 0.0, 1.0)
	
	visual_root.rotation_degrees = lerp(visual_root.rotation_degrees, target_rotation, weight)

# 播放悬浮进入动画并只修改 Visuals。
func play_hover_enter() -> void:
	if not is_transform_initialized:
		return
	
	_kill_tween(hover_tween)
	card.z_index = hover_z_index
	
	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	hover_tween.set_trans(Tween.TRANS_QUAD)
	hover_tween.set_ease(Tween.EASE_OUT)
	
	hover_tween.tween_property(visual_root, "position", original_visual_position + Vector2.UP * hover_lift, hover_enter_duration)
	hover_tween.tween_property(visual_root, "scale", original_visual_scale * hover_scale, hover_enter_duration)

# 播放悬浮退出动画并恢复 Visuals 默认状态。
func play_hover_exit() -> void:
	if not is_transform_initialized:
		return
	
	_kill_tween(hover_tween)
	card.z_index = original_z_index
	
	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	hover_tween.set_trans(Tween.TRANS_QUAD)
	hover_tween.set_ease(Tween.EASE_OUT)
	
	hover_tween.tween_property(visual_root, "position", original_visual_position, hover_exit_duration)
	hover_tween.tween_property(visual_root, "scale", original_visual_scale, hover_exit_duration)
	hover_tween.tween_property(visual_root, "rotation_degrees", original_visual_rotation, hover_exit_duration)

# 播放抽牌动画并在完成后发送 draw_finished。
func play_draw() -> void:
	if not is_transform_initialized:
		return
	
	_kill_tween(draw_tween)
	_kill_tween(hover_tween)
	
	var hidden_color := original_card_modulate
	hidden_color.a = 0.0
	
	card.modulate = hidden_color
	visual_root.position = original_visual_position + Vector2.DOWN * draw_y_offset
	visual_root.scale = original_visual_scale
	visual_root.rotation_degrees = original_visual_rotation
	
	draw_tween = create_tween()
	draw_tween.set_parallel(true)
	draw_tween.set_trans(Tween.TRANS_QUAD)
	draw_tween.set_ease(Tween.EASE_OUT)
	
	draw_tween.tween_property(card, "modulate:a", original_card_modulate.a, draw_duration)
	draw_tween.tween_property(visual_root, "position", original_visual_position, draw_duration)
	
	draw_tween.chain().tween_callback(_emit_draw_finished)

# 播放出牌动画并在完成后发送 exit_finished。
func play_card_played() -> void:
	if not is_transform_initialized:
		return
	
	_prepare_exit_animation()
	
	action_tween = create_tween()
	action_tween.set_parallel(true)
	action_tween.set_trans(Tween.TRANS_CUBIC)
	action_tween.set_ease(Tween.EASE_OUT)
	
	action_tween.tween_property(visual_root, "position", original_visual_position + Vector2.UP * play_y_offset, play_duration)
	action_tween.tween_property(visual_root, "scale", original_visual_scale * play_scale, play_duration)
	action_tween.tween_property(visual_root, "rotation_degrees", original_visual_rotation, play_duration)
	action_tween.tween_property(card, "modulate:a", 0.0, play_duration)
	
	action_tween.chain().tween_callback(_emit_exit_finished)

# 播放弃牌动画并让 Visuals 向下掉落。
func play_discard() -> void:
	if not is_transform_initialized:
		return
	
	_prepare_exit_animation()
	
	action_tween = create_tween()
	action_tween.set_parallel(true)
	action_tween.set_trans(Tween.TRANS_QUAD)
	action_tween.set_ease(Tween.EASE_IN)
	
	action_tween.tween_property(visual_root, "position", original_visual_position + Vector2.DOWN * absf(discard_y_offset), discard_duration)
	action_tween.tween_property(visual_root, "scale", original_visual_scale * discard_scale, discard_duration)
	action_tween.tween_property(visual_root, "rotation_degrees", original_visual_rotation + discard_rotation, discard_duration)
	action_tween.tween_property(card, "modulate:a", 0.0, discard_duration)
	
	action_tween.chain().tween_callback(_emit_exit_finished)

# 播放简短红色反馈并且不修改任何布局属性。
func play_error_feedback() -> void:
	if not is_transform_initialized:
		return
	
	_kill_tween(feedback_tween)
	visual_root.modulate = Color(1.0, 0.35, 0.35, original_visual_modulate.a)
	
	feedback_tween = create_tween()
	feedback_tween.set_trans(Tween.TRANS_QUAD)
	feedback_tween.set_ease(Tween.EASE_OUT)
	
	feedback_tween.tween_property(visual_root, "modulate", original_visual_modulate, 0.20)

# 取消离场动画并把视觉状态恢复到默认值。
func cancel_action_and_restore() -> void:
	_kill_tween(action_tween)
	_kill_tween(draw_tween)
	_kill_tween(hover_tween)
	
	if not is_instance_valid(card) or not is_instance_valid(visual_root):
		return
	
	card.modulate = original_card_modulate
	card.z_index = original_z_index
	card.mouse_filter = original_mouse_filter
	
	visual_root.position = original_visual_position
	visual_root.scale = original_visual_scale
	visual_root.rotation_degrees = original_visual_rotation
	visual_root.modulate = original_visual_modulate

# 开始离场前停止所有会修改 Visuals 变换的 Tween。
func _prepare_exit_animation() -> void:
	_kill_tween(hover_tween)
	_kill_tween(draw_tween)
	_kill_tween(action_tween)
	
	card.z_index = hover_z_index
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

# 安全停止一个仍然有效的 Tween。
func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()

# 抽牌动画结束后发送完成信号。
func _emit_draw_finished() -> void:
	draw_finished.emit()

# 离场动画结束后发送完成信号。
func _emit_exit_finished() -> void:
	exit_finished.emit()
