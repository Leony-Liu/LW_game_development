## 控制第一人称提灯的俯仰惯性、次级晃动与灯光闪烁。
## 只持有表现状态，模型和燃料状态由其他模块负责。
class_name LanternController
extends Node3D

const MOVEMENT_THRESHOLD: float = 0.2
const MOVEMENT_TIMEOUT: float = 0.12

@export_group("必需节点")
@export var gravity_pivot: Node3D
@export var motion_pivot: Node3D
@export var lantern_light: OmniLight3D

@export_group("俯仰惯性")
@export_range(0.0, 1.0, 0.05) var pitch_counter_ratio: float = 0.5
@export_range(0.0, 45.0, 0.5) var pitch_counter_max_degrees: float = 20.0
@export_range(0.1, 8.0, 0.1) var pitch_spring_frequency: float = 2.2
@export_range(0.5, 2.0, 0.05) var pitch_damping_ratio: float = 1.0

@export_group("行走晃动")
@export_range(0.0, 0.04, 0.001) var walk_vertical_amplitude: float = 0.01
@export_range(0.0, 0.03, 0.001) var walk_lateral_amplitude: float = 0.007
@export_range(0.0, 20.0, 0.1) var walk_frequency: float = 9.0
@export_range(0.0, 5.0, 0.1) var walk_pitch_degrees: float = 0.8
@export_range(0.0, 5.0, 0.1) var walk_roll_degrees: float = 1.0

@export_group("奔跑晃动")
@export_range(0.0, 0.04, 0.001) var sprint_vertical_amplitude: float = 0.02
@export_range(0.0, 0.03, 0.001) var sprint_lateral_amplitude: float = 0.014
@export_range(0.0, 20.0, 0.1) var sprint_frequency: float = 12.5
@export_range(0.0, 5.0, 0.1) var sprint_pitch_degrees: float = 1.5
@export_range(0.0, 5.0, 0.1) var sprint_roll_degrees: float = 2.0
@export_range(0.1, 30.0, 0.1) var motion_smoothing: float = 10.0

@export_group("火光闪烁")
@export_range(0.0, 0.3, 0.01) var flicker_energy_strength: float = 0.12
@export_range(0.0, 0.1, 0.005) var flicker_range_strength: float = 0.02
@export_range(0.02, 1.0, 0.01) var flicker_interval_min: float = 0.09
@export_range(0.02, 1.0, 0.01) var flicker_interval_max: float = 0.22
@export_range(0.1, 30.0, 0.1) var flicker_smoothing: float = 8.0

var _rng := RandomNumberGenerator.new()
var _gravity_base_rotation := Vector3.ZERO
var _pitch_target: float = 0.0
var _pitch_angle: float = 0.0
var _pitch_velocity: float = 0.0
var _base_position := Vector3.ZERO
var _base_rotation := Vector3.ZERO
var _target_position := Vector3.ZERO
var _target_rotation := Vector3.ZERO
var _motion_phase: float = 0.0
var _movement_age: float = MOVEMENT_TIMEOUT
var _base_energy: float = 0.0
var _base_range: float = 0.0
var _target_energy: float = 0.0
var _target_range: float = 0.0
var _flicker_timer: float = 0.0
var _baseline_captured: bool = false
var _lit: bool = false


# 入树时保存 Inspector 基准值，并检查必需节点。
func _ready() -> void:
	_rng.randomize()
	if not is_instance_valid(gravity_pivot):
		push_error("LanternController ： 初始化失败：缺少必需的 LanternGravityPivot 引用")
	else:
		_gravity_base_rotation = gravity_pivot.rotation
	if not is_instance_valid(motion_pivot):
		push_error("LanternController ： 初始化失败：缺少必需的 LanternMotionPivot 引用")
	else:
		_base_position = motion_pivot.position
		_base_rotation = motion_pivot.rotation
		_target_position = _base_position
		_target_rotation = _base_rotation
	if not is_instance_valid(lantern_light):
		push_error("LanternController ： 初始化失败：缺少必需的 LanternLight 引用")
		return
	_capture_light_baseline()
	_lit = lantern_light.visible
	_flicker_timer = _next_flicker_interval()


# 切换必需灯光节点，熄灭时恢复场景配置的亮度和范围。
func set_lit(enabled: bool) -> bool:
	if not is_instance_valid(lantern_light):
		push_error("LanternController ： 无法切换提灯灯光：缺少必需的 LanternLight 引用")
		return false
	if not _baseline_captured:
		_capture_light_baseline()
	_lit = enabled
	lantern_light.visible = enabled
	lantern_light.light_energy = _base_energy
	lantern_light.omni_range = _base_range
	_target_energy = _base_energy
	_target_range = _base_range
	_flicker_timer = _next_flicker_interval()
	return true


# 设置有界的反向俯仰目标，由弹簧逐帧追随。
func set_head_pitch(head_pitch: float) -> void:
	var max_angle := deg_to_rad(pitch_counter_max_degrees)
	_pitch_target = clampf(
		-head_pitch * pitch_counter_ratio,
		-max_angle,
		max_angle
	)


# 接收玩家运动数值，只设置相对摆动目标。
func update_movement(delta: float, speed: float, on_floor: bool, is_sprinting: bool) -> void:
	if not is_instance_valid(motion_pivot):
		return
	_movement_age = 0.0
	if not on_floor or speed <= MOVEMENT_THRESHOLD:
		_target_position = _base_position
		_target_rotation = _base_rotation
		_motion_phase = 0.0
		return
	var frequency := sprint_frequency if is_sprinting else walk_frequency
	var vertical := sprint_vertical_amplitude if is_sprinting else walk_vertical_amplitude
	var lateral := sprint_lateral_amplitude if is_sprinting else walk_lateral_amplitude
	var pitch := sprint_pitch_degrees if is_sprinting else walk_pitch_degrees
	var roll := sprint_roll_degrees if is_sprinting else walk_roll_degrees
	_motion_phase += maxf(delta, 0.0) * frequency
	_target_position = _base_position + Vector3(
		cos(_motion_phase * 0.5) * lateral,
		sin(_motion_phase) * vertical,
		0.0
	)
	_target_rotation = _base_rotation + Vector3(
		sin(_motion_phase) * deg_to_rad(pitch),
		0.0,
		cos(_motion_phase * 0.5) * deg_to_rad(roll)
	)


# 每帧独立更新俯仰、摆动与点燃期间的火光。
func _process(delta: float) -> void:
	_update_gravity(delta)
	_update_motion(delta)
	if not _lit or not is_instance_valid(lantern_light):
		return
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		var variation := _rng.randf_range(-1.0, 1.0)
		_target_energy = _base_energy * (1.0 + variation * flicker_energy_strength)
		_target_range = _base_range * (1.0 + variation * flicker_range_strength)
		_flicker_timer = _next_flicker_interval()
	var weight := 1.0 - exp(-flicker_smoothing * delta)
	lantern_light.light_energy = lerpf(lantern_light.light_energy, _target_energy, weight)
	lantern_light.omni_range = lerpf(lantern_light.omni_range, _target_range, weight)


# 用带阻尼的弹簧追随俯仰目标，并限制实际补偿角度。
func _update_gravity(delta: float) -> void:
	if not is_instance_valid(gravity_pivot):
		return
	var max_angle := deg_to_rad(pitch_counter_max_degrees)
	var elapsed := clampf(delta, 0.0, 0.1)
	var steps := maxi(1, ceili(elapsed / 0.004))
	var step := elapsed / steps
	var omega := TAU * pitch_spring_frequency
	for i in range(steps):
		var acceleration := (
			(_pitch_target - _pitch_angle) * omega * omega
			- 2.0 * pitch_damping_ratio * omega * _pitch_velocity
		)
		_pitch_velocity += acceleration * step
		_pitch_angle += _pitch_velocity * step
		_pitch_angle = clampf(_pitch_angle, -max_angle, max_angle)
		if absf(_pitch_angle) >= max_angle and _pitch_angle * _pitch_velocity > 0.0:
			_pitch_velocity = 0.0
	gravity_pivot.rotation = _gravity_base_rotation + Vector3(_pitch_angle, 0.0, 0.0)


# 没有新运动信号时也平滑回到初始局部变换。
func _update_motion(delta: float) -> void:
	if not is_instance_valid(motion_pivot):
		return
	_movement_age += delta
	if _movement_age > MOVEMENT_TIMEOUT:
		_target_position = _base_position
		_target_rotation = _base_rotation
	var weight := 1.0 - exp(-motion_smoothing * delta)
	motion_pivot.position = motion_pivot.position.lerp(_target_position, weight)
	motion_pivot.rotation = motion_pivot.rotation.lerp(_target_rotation, weight)


# 从场景灯光读取可调基准值。
func _capture_light_baseline() -> void:
	_base_energy = lantern_light.light_energy
	_base_range = lantern_light.omni_range
	_target_energy = _base_energy
	_target_range = _base_range
	_baseline_captured = true


# 限制随机目标的最短与最长持续时间。
func _next_flicker_interval() -> float:
	return _rng.randf_range(
		minf(flicker_interval_min, flicker_interval_max),
		maxf(flicker_interval_min, flicker_interval_max)
	)
