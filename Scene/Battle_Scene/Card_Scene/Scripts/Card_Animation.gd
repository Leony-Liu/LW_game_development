extends Node

## 弃牌动画的整体持续时间
@export var discard_duration: float = 0.15
## 弃牌时卡牌在 Y 轴上向下移动的像素距离
@export var discard_y_offset: float = -40.0
## 抽牌动画的整体持续时间
@export var draw_duration: float = 0.20

## 鼠标位于边缘时，卡牌跟随旋转的最大限制角度
@export var max_rotation: float = 5.0
## 悬停时卡牌根节点整体放大的倍数
@export var hover_scale: float = 1.1
## 悬停时卡牌在 Y 轴上向上抬起的像素距离
@export var hover_lift: float = 20.0
## 悬停状态下强制提升的 Z 轴显示层级，避免被遮挡
@export var hover_z_index: int = 100
## 卡牌根据鼠标位置实时插值旋转的跟随速度
@export var rotation_follow_speed: float = 10.0
## 悬停放大与抬高动画的持续时间
@export var hover_enter_duration: float = 0.10
## 取消悬停后恢复初始状态动画的持续时间
@export var hover_exit_duration: float = 0.15

## 获取并缓存挂载此组件的父节点（卡牌根节点）引用
@onready var card: Control = get_parent()
## 通过唯一名称绑定包含卡面所有视觉元素的控制节点
@onready var visual_root: Control = %Visuals
## 获取同级的交互组件节点，用于读取其悬停状态
@onready var interaction: Node = $"../InteractionComponent"

## 标记父节点在容器排版后的初始变换参数是否已被记录
var is_transform_initialized: bool = false
## 记录卡牌排版后的初始自定义最小尺寸（用于抽牌展开动画）
var original_minimum_size: Vector2
## 记录卡牌初始的旋转角度
var original_rotation: float
## 记录视觉根节点初始的局部位置
var original_visual_position: Vector2
## 记录视觉根节点初始的缩放比例
var original_visual_scale: Vector2
## 记录卡牌初始的 Z 轴显示层级
var original_z_index: int

## 负责执行悬停进入与退出动画的补间对象
var hover_tween: Tween
## 负责在悬停结束后平滑复位卡牌旋转角度的补间对象
var reset_rotation_tween: Tween

# 节点就绪时提取父节点初始宽度，并延迟请求执行参数记录。
func _ready() -> void:
	original_minimum_size = card.custom_minimum_size if card.custom_minimum_size.x > 0.0 else card.size
	call_deferred("_initialize_transform")

# 确认视觉节点有效后，记录卡牌与视觉根节点的初始变换数据。
func _initialize_transform() -> void:
	if not is_instance_valid(visual_root): return push_error("Visuals 节点丢失。")
	card.pivot_offset = card.size * 0.5
	visual_root.pivot_offset = visual_root.size * 0.5
	original_rotation = card.rotation_degrees
	original_visual_position = visual_root.position
	original_visual_scale = visual_root.scale
	original_z_index = card.z_index
	is_transform_initialized = true

# 提高显示层级，并通过 Tween 并发执行放大和抬高的悬停动画。
func play_hover_enter() -> void:
	original_z_index = card.z_index
	card.z_index = hover_z_index
	if hover_tween: hover_tween.kill()
	hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(visual_root, "scale", original_visual_scale * hover_scale, hover_enter_duration)
	hover_tween.tween_property(visual_root, "position", original_visual_position + Vector2.UP * hover_lift, hover_enter_duration)

# 恢复初始显示层级，通过 Tween 并发执行尺寸与位置的复位动画。
func play_hover_exit() -> void:
	card.z_index = original_z_index
	if hover_tween: hover_tween.kill()
	if reset_rotation_tween: reset_rotation_tween.kill()
	hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(visual_root, "scale", original_visual_scale, hover_exit_duration)
	hover_tween.tween_property(visual_root, "position", original_visual_position, hover_exit_duration)
	reset_rotation_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reset_rotation_tween.tween_property(card, "rotation_degrees", original_rotation, hover_exit_duration)

# 每帧检查悬停与初始化状态，根据鼠标水平偏移量平滑插值计算旋转角度。
func _process(delta: float) -> void:
	if not interaction.is_hovered or card.get("is_locked") or not is_transform_initialized or card.size.x <= 0.0: return
	var h_offset := clampf((card.get_local_mouse_position().x - card.size.x * 0.5) / (card.size.x * 0.5), -1.0, 1.0)
	card.rotation_degrees = lerp(card.rotation_degrees, original_rotation + h_offset * max_rotation, clampf(rotation_follow_speed * delta, 0.0, 1.0))

# 更改卡牌颜色为红色并通过一系列短暂的 Tween 改变 X 坐标实现抖动效果。
func play_error_shake() -> void:
	card.modulate = Color(1.0, 0.2, 0.2, 1.0)
	var tween := create_tween()
	tween.tween_property(card, "position:x", card.position.x - 10.0, 0.05)
	tween.tween_property(card, "position:x", card.position.x + 10.0, 0.05)
	tween.tween_property(card, "position:x", card.position.x, 0.05)
	tween.tween_property(card, "modulate", Color.WHITE, 0.15)

# 屏蔽交互并提高层级，通过 Tween 使卡牌向下移动并淡出，最后自动销毁。
func play_discard() -> void:
	if hover_tween: hover_tween.kill()
	if reset_rotation_tween: reset_rotation_tween.kill()
	card.z_index = hover_z_index
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "modulate:a", 0.0, discard_duration)
	tween.tween_property(card, "position:y", card.position.y + discard_y_offset, discard_duration)
	tween.chain().tween_callback(card.queue_free)

# 将卡牌宽度和透明度归零，通过 Tween 平滑展开宽度并淡入显现。
func play_draw() -> void:
	var target_width := original_minimum_size.x if original_minimum_size.x > 0.0 else card.size.x
	card.custom_minimum_size.x = 0.0
	card.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "custom_minimum_size:x", target_width, draw_duration)
	tween.tween_property(card, "modulate:a", 1.0, draw_duration)
