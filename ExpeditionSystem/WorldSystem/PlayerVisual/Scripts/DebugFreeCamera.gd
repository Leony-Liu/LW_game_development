class_name DebugFreeCamera
extends Camera3D

@export_group("移动速度")
@export var normal_speed: float = 10.0
@export var sprint_speed: float = 25.0
@export var slow_speed: float = 3.0
@export var acceleration: float = 15.0

@export_group("视角控制")
@export var mouse_sensitivity: float = 0.002
@export_range(60.0, 89.0) var max_pitch_deg: float = 89.0

var is_active: bool = false
var _current_velocity: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	# 鼠标环顾：解算为偏航角 (Yaw) 与俯仰角 (Pitch)
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, deg_to_rad(-max_pitch_deg), deg_to_rad(max_pitch_deg))

		# 独立设置四元数/欧拉角，杜绝滚转漂移与万向节锁死
		rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	if not is_active:
		return

	# 1. 计算三维移动输入向量（前后、左右、垂直升降）
	var move_input := Vector3.ZERO

	# 前后 (W / S)
	if Input.is_key_pressed(KEY_W):
		move_input.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_input.z += 1.0

	# 左右 (A / D)
	if Input.is_key_pressed(KEY_A):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_input.x += 1.0

	# 升降 (E 或 空格 上升，Q 或 Ctrl 下降)
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		move_input.y += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		move_input.y -= 1.0

	# 2. 匹配移动档位（Shift 加速，Alt 减速微调）
	var target_speed := normal_speed
	if Input.is_key_pressed(KEY_SHIFT):
		target_speed = sprint_speed
	elif Input.is_key_pressed(KEY_ALT):
		target_speed = slow_speed

	# 3. 将相机局部视线方向转化为世界平移方向
	var move_direction := (transform.basis * move_input.normalized()).normalized()
	var target_velocity := move_direction * target_speed

	# 惯性平滑插值
	_current_velocity = _current_velocity.lerp(target_velocity, acceleration * delta)
	global_position += _current_velocity * delta


## 响应 PlayerVisualManager 调度的权限开关
func set_active(active: bool) -> void:
	is_active = active
	set_process(active)
	set_process_unhandled_input(active)

	if active:
		# 激活时读取同步过来的真实欧拉角，防止转动时出现视线瞬跳
		_yaw = rotation.y
		_pitch = rotation.x
		_current_velocity = Vector3.ZERO
