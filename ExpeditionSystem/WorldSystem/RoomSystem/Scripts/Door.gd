class_name Door
extends Node3D

signal door_opened(door:Node3D)

@export_group("节点引用")
## 包含 Mesh 和碰撞箱的门体实体
@export var door_body: StaticBody3D
## 固定的检测区域
@export var interaction_area: Area3D

@export_group("开门参数")
## 门下沉的深度（单位：米）
@export var open_depth: float = 3.0
## 自动关门的距离阈值（单位：米）
@export var auto_close_distance: float = 2.0
## 开关门动画时长（秒）
@export var anim_duration: float = 0.5

# 状态变量
var is_open: bool = false
var is_animating: bool = false
var current_player: CharacterBody3D = null
var initial_body_y: float = 0.0


func _ready() -> void:
	if not door_body:
		door_body = $StaticBody3D
	if not interaction_area:
		interaction_area = $InteractionArea
		
	initial_body_y = door_body.position.y

	# 动态连接检测区域信号
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	# 门处于关闭状态、玩家在交互范围内、按 E 键触发开门
	if not is_open and not is_animating and current_player != null:
		if event is InputEventKey and event.pressed and event.keycode == KEY_E:
			open_door()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# 门打开后持续检测：当玩家与门的水平距离超过 2m 时自动关门
	if is_open and not is_animating:
		if current_player:
			var door_pos_2d := Vector2(global_position.x, global_position.z)
			var player_pos_2d := Vector2(current_player.global_position.x, current_player.global_position.z)
			var distance := door_pos_2d.distance_to(player_pos_2d)

			if distance > auto_close_distance:
				close_door()
		else:
			# 玩家已完全离开检测体且指针为空，直接关门
			close_door()


## 开门逻辑：向 -Y 方向平滑下沉 3m
func open_door() -> void:
	is_animating = true
	var target_y := initial_body_y - open_depth
	
	var tween := create_tween()
	tween.tween_property(door_body, "position:y", target_y, anim_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
	tween.finished.connect(func():
		is_open = true
		is_animating = false
		door_opened.emit(self)
	)


## 关门逻辑：回到初始 Y 轴位置并阻挡通路
func close_door() -> void:
	is_animating = true
	is_open = false
	
	var tween := create_tween()
	tween.tween_property(door_body, "position:y", initial_body_y, anim_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)
		
	tween.finished.connect(func():
		is_animating = false
	)


# ==============================================================================
# 检测区域触发逻辑
# ==============================================================================

func _on_interaction_area_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		current_player = body


func _on_interaction_area_body_exited(body: Node3D) -> void:
	if body == current_player:
		# 玩家走出检测区，清空引用；若门开着，_process 会立即将其关闭
		current_player = null
