extends Node
class_name CameraDebugSwitcher


@export_category("Cameras")

@export var gameplay_camera: Camera3D
@export var debug_camera: Camera3D


@export_category("Debug")

## 调试镜头切换键。
## 不使用 InputMap，不修改 project.godot。
@export var switch_key: Key = KEY_L


var using_debug_camera: bool = false


func _ready() -> void:
	if gameplay_camera == null:
		push_error(
			"CameraDebugSwitcher: Gameplay Camera 未设置。"
		)
		return

	if debug_camera == null:
		push_error(
			"CameraDebugSwitcher: Debug Camera 未设置。"
		)
		return

	gameplay_camera.make_current()

	using_debug_camera = false

	print(
		"[CameraDebugSwitcher] Ready"
	)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event: InputEventKey = (
		event as InputEventKey
	)

	if not key_event.pressed:
		return

	if key_event.echo:
		return

	if key_event.keycode != switch_key:
		return

	_toggle_camera()


func _toggle_camera() -> void:
	using_debug_camera = not using_debug_camera

	if using_debug_camera:
		debug_camera.make_current()

		print(
			"[CameraDebugSwitcher] DEBUG CAMERA"
		)

	else:
		gameplay_camera.make_current()

		print(
			"[CameraDebugSwitcher] GAMEPLAY CAMERA"
		)
