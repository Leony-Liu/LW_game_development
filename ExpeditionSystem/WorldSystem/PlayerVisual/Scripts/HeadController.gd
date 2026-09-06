class_name HeadController
extends Node3D

@export var mouse_sensitivity: float = 0.002
var is_active: bool = true


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		rotate_x(-event.relative.y * mouse_sensitivity)
		rotation.x = clamp(rotation.x, deg_to_rad(-89), deg_to_rad(89))

func set_active(active: bool) -> void:
	is_active = active
