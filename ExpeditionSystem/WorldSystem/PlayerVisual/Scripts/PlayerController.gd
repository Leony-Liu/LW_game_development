## 处理探索移动、身体水平视角与遇敌接近运动。
## 运镜复用真实 CharacterBody3D 与碰撞，不接收手动输入。
class_name PlayerController
extends CharacterBody3D

signal movement_state_changed(delta: float, current_speed: float, is_on_floor: bool, is_sprinting: bool)
signal cinematic_approach_finished(approach_id: int, succeeded: bool)

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
var _approach_active: bool = false
var _approach_id: int = -1
var _approach_target: Node3D = null
var _approach_head: HeadController = null
var _approach_speed: float = 0.0
var _approach_stop_distance: float = 0.0
var _approach_turn_speed: float = 0.0
var _approach_settle_time: float = 0.0
var _approach_max_duration: float = 0.0
var _approach_elapsed: float = 0.0
var _approach_settle_elapsed: float = 0.0

const APPROACH_DISTANCE_TOLERANCE: float = 0.05
const APPROACH_FACING_TOLERANCE: float = 0.035


# 启动时锁定并隐藏鼠标。
func _ready() -> void:
	# 启动时锁定并隐藏鼠标
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# 处理鼠标释放、重新捕获与探索视角输入。
func _unhandled_input(event: InputEvent) -> void:
	# 1. 按 ESC 释放鼠标（方便关闭调试窗口或点击其他界面）
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	# 非探索阶段不允许左键重新捕获鼠标。
	if not is_active:
		return

	# 2. 鼠标释放状态下，左键点击游戏视口重新锁定鼠标
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	# 3. 仅在鼠标锁定时处理旋转
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	# 身体仅处理水平偏航 (Yaw)
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)


# 运行遇敌接近或普通探索移动。
func _physics_process(delta: float) -> void:
	if _approach_active:
		_process_cinematic_approach(delta)
		return
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


# 启动一次带身份的自动接近；参数由 PlayerVisualManager 的 Inspector 配置。
func start_cinematic_approach(
	target: Node3D,
	view_head: HeadController,
	approach_id: int,
	move_speed: float,
	stop_distance: float,
	turn_speed: float,
	settle_time: float,
	max_duration: float
) -> bool:
	if _approach_active or not is_instance_valid(target) or not target.is_inside_tree():
		return false
	if not is_instance_valid(view_head):
		return false
	if move_speed <= 0.0 or stop_distance <= 0.0 or turn_speed <= 0.0:
		return false

	is_active = false
	velocity = Vector3.ZERO
	_approach_active = true
	_approach_id = approach_id
	_approach_target = target
	_approach_head = view_head
	_approach_speed = move_speed
	_approach_stop_distance = stop_distance
	_approach_turn_speed = turn_speed
	_approach_settle_time = maxf(settle_time, 0.0)
	_approach_max_duration = maxf(max_duration, 0.1)
	_approach_elapsed = 0.0
	_approach_settle_elapsed = 0.0
	return true


# 逐物理帧移动并转向目标，完成条件由距离、朝向和稳定时间共同决定。
func _process_cinematic_approach(delta: float) -> void:
	_approach_elapsed += delta
	if _approach_elapsed > _approach_max_duration:
		_finish_cinematic_approach(false)
		return
	if not is_instance_valid(_approach_target) or not _approach_target.is_inside_tree():
		_finish_cinematic_approach(false)
		return
	if not is_instance_valid(_approach_head):
		_finish_cinematic_approach(false)
		return

	var target_position := _approach_target.global_position
	var flat_offset := target_position - global_position
	flat_offset.y = 0.0
	var distance_to_target := flat_offset.length()
	var direction := flat_offset.normalized() if distance_to_target > 0.0001 else Vector3.ZERO
	var body_ready := _smooth_face_direction(direction, delta)
	var head_ready := _approach_head.smooth_face_world_position(
		target_position,
		_approach_turn_speed,
		delta,
		APPROACH_FACING_TOLERANCE
	)

	var reached_distance := distance_to_target <= (
		_approach_stop_distance + APPROACH_DISTANCE_TOLERANCE
	)
	if reached_distance:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var remaining_distance := maxf(distance_to_target - _approach_stop_distance, 0.0)
		var desired_speed := minf(_approach_speed, remaining_distance / maxf(delta, 0.0001))
		velocity.x = move_toward(velocity.x, direction.x * desired_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * desired_speed, acceleration * delta)
		var horizontal_velocity := Vector2(velocity.x, velocity.z)
		if horizontal_velocity.length() > desired_speed:
			horizontal_velocity = horizontal_velocity.normalized() * desired_speed
			velocity.x = horizontal_velocity.x
			velocity.z = horizontal_velocity.y

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	var current_horizontal_speed := Vector2(velocity.x, velocity.z).length()
	movement_state_changed.emit(delta, current_horizontal_speed, is_on_floor(), false)

	if reached_distance and body_ready and head_ready and current_horizontal_speed <= 0.05:
		_approach_settle_elapsed += delta
		if _approach_settle_elapsed >= _approach_settle_time:
			_finish_cinematic_approach(true)
	else:
		_approach_settle_elapsed = 0.0


# 平滑转动身体偏航，并返回水平朝向是否就绪。
func _smooth_face_direction(direction: Vector3, delta: float) -> bool:
	if direction.is_zero_approx():
		return true
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = rotate_toward(rotation.y, target_yaw, _approach_turn_speed * delta)
	return absf(angle_difference(rotation.y, target_yaw)) <= APPROACH_FACING_TOLERANCE


# 结束自动接近并仅发送一次带身份的完成结果。
func _finish_cinematic_approach(succeeded: bool) -> void:
	if not _approach_active:
		return
	var finished_id := _approach_id
	_clear_cinematic_approach()
	cinematic_approach_finished.emit(finished_id, succeeded)


# 取消指定自动接近，不伪造完成回调。
func cancel_cinematic_approach(approach_id: int = -1) -> bool:
	if not _approach_active:
		return false
	if approach_id >= 0 and approach_id != _approach_id:
		return false
	_clear_cinematic_approach()
	return true


# 清空自动接近的临时引用和速度。
func _clear_cinematic_approach() -> void:
	_approach_active = false
	_approach_id = -1
	_approach_target = null
	_approach_head = null
	_approach_elapsed = 0.0
	_approach_settle_elapsed = 0.0
	velocity = Vector3.ZERO


# 查询当前是否正在执行自动接近。
func is_cinematic_approach_active() -> bool:
	return _approach_active


# 启停探索控制，并在停用时清空残余速度。
func set_active(active: bool) -> void:
	is_active = active
	if not active:
		velocity = Vector3.ZERO
