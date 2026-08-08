extends Camera3D
class_name ShelterCamera


# ============================================================
# Shelter Camera
#
# 固定方向 + 跟随玩家平移
#
# Camera 与 Player 是兄弟节点：
#
# Shelter
# ├── Camera3D
# └── ShelterPlayer
#
# Camera 不继承 Player 的旋转，
# 因此玩家转身不会带着镜头旋转。
# ============================================================


@export_category("Target")

## 正式场景中建议手动拖入 ShelterPlayer。
## 如果忘记设置，会自动寻找同级名为 ShelterPlayer 的节点。
@export var target: Node3D


@export_category("Follow")

## 摄像机相对玩家的位置
@export var camera_offset: Vector3 = Vector3(
	6.0,
	6.0,
	6.0
)

## 摄像机看向玩家身体的高度
@export var look_height: float = 1.0

## 跟随速度
@export_range(0.1, 30.0, 0.1)
var follow_speed: float = 12.0

## 是否使用平滑跟随
@export var smooth_follow: bool = true


func _ready() -> void:
	# --------------------------------------------------------
	# 非常重要：
	# 先确保当前 Camera 可用。
	#
	# 即使 Target 配置有问题，也不能因为提前 return
	# 导致整个游戏没有活动摄像机。
	# --------------------------------------------------------
	current = true

	_resolve_target()

	if target == null:
		push_error(
			"ShelterCamera: 找不到 ShelterPlayer。"
			+ "请检查 Camera3D 的 Target。"
		)
		return

	# 出生第一帧直接移动到正确位置。
	global_position = _get_desired_position()

	_update_rotation()


func _process(delta: float) -> void:
	if target == null:
		return

	var desired_position: Vector3 = (
		_get_desired_position()
	)

	if smooth_follow:
		var follow_weight: float = (
			1.0
			- exp(-follow_speed * delta)
		)

		global_position = global_position.lerp(
			desired_position,
			follow_weight
		)

	else:
		global_position = desired_position




# ============================================================
# Target
# ============================================================


func _resolve_target() -> void:
	# Inspector 已经设置就直接使用。
	if target != null:
		return

	# Camera 和 Player 当前都是 Shelter 的直接子节点，
	# 因此可以自动寻找同级 ShelterPlayer。
	var parent_node: Node = get_parent()

	if parent_node == null:
		return

	var found_player: Node = (
		parent_node.get_node_or_null(
			"ShelterPlayer"
		)
	)

	if found_player is Node3D:
		target = found_player as Node3D


# ============================================================
# Position / Rotation
# ============================================================


func _get_desired_position() -> Vector3:
	return (
		target.global_position
		+ camera_offset
	)


func _update_rotation() -> void:
	if target == null:
		return

	var look_target: Vector3 = (
		target.global_position
		+ Vector3.UP * look_height
	)

	var look_direction: Vector3 = (
		look_target - global_position
	)

	# Camera 与目标位置完全重合时无法计算朝向
	if look_direction.length_squared() < 0.000001:
		return

	look_direction = look_direction.normalized()

	var up_vector: Vector3 = Vector3.UP

	# 如果观察方向与世界 UP 几乎平行，
	# Vector3.UP 无法作为稳定的上方向。
	#
	# 这种情况通常发生在 Camera 位于 Player 正上方时。
	if absf(look_direction.dot(Vector3.UP)) > 0.999:
		up_vector = Vector3.FORWARD

	look_at(
		look_target,
		up_vector
	)
