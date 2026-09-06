class_name PlayerController
extends CharacterBody3D

signal movement_state_changed(delta: float, current_speed: float, is_on_floor: bool, is_sprinting: bool)

@export_group("移速配置")
## 步行速度
@export var walk_speed: float = 3.5
## 奔跑速度
@export var sprint_speed: float = 6.5
## 加速度
@export var acceleration: float = 10.0
## 鼠标灵敏度
@export var mouse_sensitivity: float = 0.001

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_active: bool = true


func _ready() -> void:
	# 启动时锁定并隐藏鼠标
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	# 1. 按 ESC 释放鼠标（方便关闭调试窗口或点击其他界面）
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	# 2. 鼠标释放状态下，左键点击游戏视口重新锁定鼠标
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	# 3. 仅在被激活且鼠标锁定时处理旋转
	if not is_active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	# 身体仅处理水平偏航 (Yaw)
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# 重力衰落
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 1. 采集原生 WASD 移动向量（无需预先配置 InputMap）
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	# 2. 判断奔跑状态：按住左 Shift 且正在向前移动
	var is_sprinting := Input.is_key_pressed(KEY_SHIFT) and input_dir.y < 0.0
	var target_speed := sprint_speed if is_sprinting else walk_speed

	# 3. 计算基于身体朝向的世界坐标移动方向
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	# 4. 水平速度插值计算
	if direction:
		velocity.x = lerp(velocity.x, direction.x * target_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * target_speed, acceleration * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, acceleration * delta)

	move_and_slide()

	# 5. 发送信号驱动 HeadBob 晃动
	var current_horizontal_speed := Vector2(velocity.x, velocity.z).length()
	movement_state_changed.emit(delta, current_horizontal_speed, is_on_floor(), is_sprinting)


func set_active(active: bool) -> void:
	is_active = active
	if not active:
		velocity = Vector3.ZERO
