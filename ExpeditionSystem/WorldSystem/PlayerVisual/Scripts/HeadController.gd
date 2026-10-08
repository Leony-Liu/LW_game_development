## 处理第一人称视角的垂直旋转。
## 探索时读取鼠标，遇敌运镜时提供受控朝向方法。
class_name HeadController
extends Node3D

@export var mouse_sensitivity: float = 0.002
var is_active: bool = true


# 仅在探索输入激活且鼠标被捕获时响应视角移动。
func _unhandled_input(event: InputEvent) -> void:
	if not is_active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		rotate_x(-event.relative.y * mouse_sensitivity)
		rotation.x = clamp(rotation.x, deg_to_rad(-60), deg_to_rad(60))


# 平滑朝向世界空间目标，并返回垂直视角是否就绪。
func smooth_face_world_position(
	world_target: Vector3,
	turn_speed: float,
	delta: float,
	tolerance_radians: float
) -> bool:
	var parent_3d := get_parent_node_3d()
	if parent_3d == null:
		return false
	var target_in_parent := parent_3d.to_local(world_target)
	var direction := target_in_parent - position
	var horizontal_distance := Vector2(direction.x, direction.z).length()
	var target_pitch := atan2(direction.y, horizontal_distance)
	target_pitch = clampf(target_pitch, deg_to_rad(-60.0), deg_to_rad(60.0))
	rotation.x = rotate_toward(rotation.x, target_pitch, turn_speed * delta)
	return absf(angle_difference(rotation.x, target_pitch)) <= tolerance_radians


# 启停探索鼠标视角。
func set_active(active: bool) -> void:
	is_active = active
