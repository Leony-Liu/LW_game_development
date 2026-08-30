# 动画效果节点
extends Node

#region 暴露的视觉与动画参数
@export_category("UI Colors")
@export var attack_cost_color: Color = Color("ff7700")
@export var skill_cost_color: Color = Color("00bfff")

@export_category("Animation Config")
@export var discard_duration: float = 0.15
@export var discard_y_offset: float = -40.0
@export var draw_duration: float = 0.20
@export var max_rotation: float = 5.0
@export var hover_scale: float = 1.1
@export var hover_lift: float = 20.0
@export var hover_z_index: int = 100
@export var rotation_follow_speed: float = 10.0
@export var hover_enter_duration: float = 0.10
@export var hover_exit_duration: float = 0.15
#endregion

# 节点引用
var card: Control
var visual_root: Control

var is_transform_initialized: bool = false
var original_minimum_size: Vector2
var original_rotation: float
var original_visual_position: Vector2
var original_visual_scale: Vector2
var original_z_index: int

var hover_tween: Tween
var reset_rotation_tween: Tween


func setup(p_card: Control, p_visual_root: Control) -> void:
	card = p_card
	visual_root = p_visual_root
	original_minimum_size = card.custom_minimum_size if card.custom_minimum_size.x > 0.0 else card.size
	call_deferred("_initialize_transform")

func _initialize_transform() -> void:
	if not is_instance_valid(visual_root): return push_error("Visuals 节点丢失。")
	card.pivot_offset = card.size * 0.5
	visual_root.pivot_offset = visual_root.size * 0.5
	original_rotation = card.rotation_degrees
	original_visual_position = visual_root.position
	original_visual_scale = visual_root.scale
	original_z_index = card.z_index
	is_transform_initialized = true

# 修改文本颜色等视觉表现
func set_cost_color(label: Label, is_attack: bool) -> void:
	label.add_theme_color_override("font_color", attack_cost_color if is_attack else skill_cost_color)

# 动态插值计算旋转（由 Logic 在 _process 中主动调用）
func update_dynamic_rotation(delta: float, mouse_x: float, card_width: float) -> void:
	if not is_transform_initialized or card_width <= 0.0: return
	var h_offset := clampf((mouse_x - card_width * 0.5) / (card_width * 0.5), -1.0, 1.0)
	card.rotation_degrees = lerp(card.rotation_degrees, original_rotation + h_offset * max_rotation, clampf(rotation_follow_speed * delta, 0.0, 1.0))

func play_hover_enter() -> void:
	if not is_transform_initialized: return
	original_z_index = card.z_index
	card.z_index = hover_z_index
	if hover_tween: hover_tween.kill()
	hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(visual_root, "scale", original_visual_scale * hover_scale, hover_enter_duration)
	hover_tween.tween_property(visual_root, "position", original_visual_position + Vector2.UP * hover_lift, hover_enter_duration)

func play_hover_exit() -> void:
	if not is_transform_initialized: return
	card.z_index = original_z_index
	if hover_tween: hover_tween.kill()
	if reset_rotation_tween: reset_rotation_tween.kill()
	hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(visual_root, "scale", original_visual_scale, hover_exit_duration)
	hover_tween.tween_property(visual_root, "position", original_visual_position, hover_exit_duration)
	reset_rotation_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reset_rotation_tween.tween_property(card, "rotation_degrees", original_rotation, hover_exit_duration)

func play_error_shake() -> void:
	card.modulate = Color(1.0, 0.2, 0.2, 1.0)
	var tween := create_tween()
	tween.tween_property(card, "position:x", card.position.x - 10.0, 0.05)
	tween.tween_property(card, "position:x", card.position.x + 10.0, 0.05)
	tween.tween_property(card, "position:x", card.position.x, 0.05)
	tween.tween_property(card, "modulate", Color.WHITE, 0.15)

# 出牌动画：放大、向上移动、透明度变0
func play_card_played() -> void:
	if hover_tween: hover_tween.kill()
	if reset_rotation_tween: reset_rotation_tween.kill()
	card.z_index = hover_z_index
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 注意这里改为移动 visual_root，与手牌整体滑动互不干扰
	tween.tween_property(visual_root, "scale", original_visual_scale * 1.2, 0.2)
	tween.tween_property(visual_root, "position:y", original_visual_position.y - 80.0, 0.2)
	tween.tween_property(card, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(card.queue_free)

# 弃牌动画：向下移动、透明度变0
func play_discard() -> void:
	if hover_tween: hover_tween.kill()
	if reset_rotation_tween: reset_rotation_tween.kill()
	card.z_index = hover_z_index
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "modulate:a", 0.0, discard_duration)
	tween.tween_property(visual_root, "position:y", original_visual_position.y + discard_y_offset, discard_duration)
	tween.chain().tween_callback(card.queue_free)

func play_draw() -> void:
	var target_width := original_minimum_size.x if original_minimum_size.x > 0.0 else card.size.x
	card.custom_minimum_size.x = 0.0
	card.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "custom_minimum_size:x", target_width, draw_duration)
	tween.tween_property(card, "modulate:a", 1.0, draw_duration)
