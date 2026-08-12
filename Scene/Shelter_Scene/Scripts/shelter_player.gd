extends CharacterBody3D
class_name ShelterPlayer


# ============================================================
# Shelter Player
#
# 基地玩家的基础移动控制器。
#
# 当前职责：
# - WASD 输入
# - 摄像机相对移动
# - 平滑加速 / 减速
# - 重力
# - 自动朝向移动方向
# - Idle / Move 动画切换
#
# 后续交互、建造、UI 输入锁定不会直接塞进这里，
# 而是通过独立组件或状态控制。
# ============================================================


@export_category("Movement")

## 正常行走速度
@export var walk_speed: float = 1.1

## 按住 Shift 时的奔跑速度
@export var run_speed: float = 4.5

## 加速度
@export var acceleration: float = 18.0

## 松开方向键后的减速度
@export var deceleration: float = 22.0

## 模型朝向目标方向的速度
@export var rotation_speed: float = 12.0


@export_category("References")

## 视觉模型的旋转根节点
@export var visual_root: Node3D

## 用于决定 WASD 世界方向的参考节点。
## 基地中设置为当前 Camera3D。
@export var movement_reference: Node3D

## 角色动画播放器
@export var animation_player: AnimationPlayer


@export_category("Model Orientation")

## 模型自身的朝向补偿。
##
## 如果运行后角色一直背对移动方向：
## 0 -> 改为 180
@export_range(-180.0, 180.0, 1.0)
var model_yaw_offset_degrees: float = 0.0


@export_category("Animation")

## 站立
@export var idle_animation: StringName = &"Idle"

## 普通移动
@export var walk_animation: StringName = &"Walk"

## Shift 奔跑
## 使用之前的 Jog_Fwd 动画
@export var run_animation: StringName = &"Jog_Fwd"

## Idle / Jog 的过渡时间
@export_range(0.0, 1.0, 0.01)
var animation_blend_time: float = 0.15


var _current_animation: StringName = &""

## 当前是否处于奔跑状态
var is_running: bool = false


func _ready() -> void:
	_validate_setup()
	_play_animation(idle_animation)


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)

	var input_vector := Input.get_vector(
		"Left",
		"Right",
		"Up",
		"Down"
	)

	var move_direction := _calculate_move_direction(
		input_vector
	)

	# ========================================================
	# Sprint
	#
	# 当前只在 ShelterPlayer 内监听 Shift，
	# 不创建新的 Project Input Action，
	# 避免修改公共 project.godot。
	# ========================================================

	is_running = (
		Input.is_physical_key_pressed(KEY_SHIFT)
		and not input_vector.is_zero_approx()
	)

	var target_speed: float = (
		run_speed
		if is_running
		else walk_speed
	)

	_update_velocity(
		move_direction,
		target_speed,
		delta
	)

	_update_facing(
		move_direction,
		delta
	)

	move_and_slide()

	_update_animation()


# ============================================================
# Movement
# ============================================================


func _calculate_move_direction(input_vector: Vector2) -> Vector3:
	if input_vector.is_zero_approx():
		return Vector3.ZERO

	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT

	if movement_reference != null:
		# Godot Camera3D 的观察方向为本地 -Z。
		forward = -movement_reference.global_basis.z
		right = movement_reference.global_basis.x

	# 基地只允许水平移动。
	forward.y = 0.0
	right.y = 0.0

	if not forward.is_zero_approx():
		forward = forward.normalized()

	if not right.is_zero_approx():
		right = right.normalized()

	# Input.get_vector 中：
	#
	# W = Y负方向
	# S = Y正方向
	#
	# 因此这里需要 -input_vector.y。
	var direction := (
		right * input_vector.x
		+ forward * -input_vector.y
	)

	# 保证 W+D 不会比单独 W 更快。
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	return direction


func _update_velocity(
	move_direction: Vector3,
	target_speed: float,
	delta: float
) -> void:

	if move_direction != Vector3.ZERO:
		var target_velocity: Vector3 = (
			move_direction * target_speed
		)

		velocity.x = move_toward(
			velocity.x,
			target_velocity.x,
			acceleration * delta
		)

		velocity.z = move_toward(
			velocity.z,
			target_velocity.z,
			acceleration * delta
		)

	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration * delta
		)

		velocity.z = move_toward(
			velocity.z,
			0.0,
			deceleration * delta
		)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


# ============================================================
# Facing
# ============================================================


func _update_facing(
	move_direction: Vector3,
	delta: float
) -> void:

	if visual_root == null:
		return

	if move_direction.length_squared() < 0.001:
		return

	# 当前以模型 +Z 作为视觉正面计算。
	#
	# 如果模型实际正面为 -Z，
	# 只需要将 Model Yaw Offset 改为 180。
	var target_rotation := atan2(
		move_direction.x,
		move_direction.z
	)

	target_rotation += deg_to_rad(
		model_yaw_offset_degrees
	)

	var rotation_weight: float = clampf(
	rotation_speed * delta,
	0.0,
	1.0
)

	visual_root.rotation.y = lerp_angle(
		visual_root.rotation.y,
		target_rotation,
		rotation_weight
	)


# ============================================================
# Animation
# ============================================================


func _update_animation() -> void:
	var horizontal_speed: float = Vector2(
		velocity.x,
		velocity.z
	).length()

	# 已经基本停止
	if horizontal_speed <= 0.15:
		_play_animation(
			idle_animation
		)
		return

	# 移动中 + Shift
	if is_running:
		_play_animation(
			run_animation
		)
		return

	# 普通移动
	_play_animation(
		walk_animation
	)


func _play_animation(animation_name: StringName) -> void:
	if animation_player == null:
		return

	if _current_animation == animation_name:
		return

	if not animation_player.has_animation(animation_name):
		push_warning(
			"ShelterPlayer: 找不到动画 '%s'"
			% animation_name
		)
		return

	animation_player.play(
		animation_name,
		animation_blend_time
	)

	_current_animation = animation_name


# ============================================================
# Validation
# ============================================================


func _validate_setup() -> void:
	if visual_root == null:
		push_error(
			"ShelterPlayer: Visual Root 没有设置。"
		)

	if movement_reference == null:
		push_warning(
			"ShelterPlayer: Movement Reference 尚未设置。"
			+ "目前将使用世界坐标方向移动。"
		)

	if animation_player == null:
		push_warning(
			"ShelterPlayer: Animation Player 尚未设置。"
			+ "角色仍可以移动，但不会播放动画。"
		)
