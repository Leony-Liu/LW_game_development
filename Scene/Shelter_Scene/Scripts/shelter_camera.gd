extends Camera3D
class_name ShelterCamera


@export_category("Target")

@export var target: Node3D


@export_category("Camera")

@export var camera_offset: Vector3 = Vector3(
	4.0,
	7.0,
	7.0
)

@export var look_height: float = 1.0


func _ready() -> void:
	# 无论 Target 是否正确，先保证场景有活动 Camera。
	make_current()

	if target == null:
		push_error(
			"ShelterCamera: Target 未设置。"
		)
		return

	_update_camera_transform()


func _physics_process(_delta: float) -> void:
	if target == null:
		return

	_update_camera_transform()


func _update_camera_transform() -> void:
	# Camera 始终保持在 Player 的固定世界空间偏移。
	global_position = (
		target.global_position
		+ camera_offset
	)

	var look_target: Vector3 = (
		target.global_position
		+ Vector3.UP * look_height
	)

	look_at(
		look_target,
		Vector3.UP
	)
