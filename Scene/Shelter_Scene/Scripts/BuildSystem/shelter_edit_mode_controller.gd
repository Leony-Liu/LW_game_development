extends Node
class_name ShelterEditModeController


# ============================================================
# Shelter Edit Mode Controller
# ============================================================
#
# NONE
#     正常玩家控制
#
# FACILITY_BUILD
#     Left Ctrl
#     编辑单个房间内部设施
#
# ROOM_LAYOUT
#     F2（开发期）
#     编辑整个基地的房间布局
#
#
# 正式 UI 完成以后，
# UI 可以直接调用：
#
# set_mode(EditMode.FACILITY_BUILD)
# set_mode(EditMode.ROOM_LAYOUT)
# set_mode(EditMode.NONE)
#
# 不需要继续依赖快捷键。
# ============================================================


signal edit_mode_changed(
	mode: int
)


enum EditMode {
	NONE,
	FACILITY_BUILD,
	ROOM_LAYOUT
}


@export_category("References")

@export var player: ShelterPlayer

@export var gameplay_camera: ShelterCamera

@export var room_build_controller: ShelterRoomBuildController

@export var facility_build_controller: ShelterFacilityBuildController

@export_category("Temporary Input")

## 房间布局模式的开发期入口。
##
## 后续正式 UI 完成后可以不再使用。
@export var room_layout_key: Key = KEY_F2


var current_mode: int = EditMode.NONE


func _ready() -> void:
	set_mode(
		EditMode.NONE
	)


func _unhandled_input(
	event: InputEvent
) -> void:
	if not event is InputEventKey:
		return

	var key_event := (
		event as InputEventKey
	)

	if not key_event.pressed:
		return

	if key_event.echo:
		return

	# --------------------------------------------------------
	# Left Ctrl
	# Facility Build
	# --------------------------------------------------------

	if _is_left_ctrl(key_event):
		_toggle_mode(
			EditMode.FACILITY_BUILD
		)

		get_viewport().set_input_as_handled()
		return

	# --------------------------------------------------------
	# Room Layout
	# --------------------------------------------------------

	if (
		key_event.keycode
		== room_layout_key
	):
		_toggle_mode(
			EditMode.ROOM_LAYOUT
		)

		get_viewport().set_input_as_handled()
		return


# ============================================================
# Public API
# ============================================================


func set_mode(
	new_mode: int
) -> void:
	if current_mode == new_mode:
		return

	# --------------------------------------------------------
	# 先关闭所有编辑子系统。
	# --------------------------------------------------------

	if room_build_controller != null:
		room_build_controller.set_room_layout_enabled(
			false
		)

	if facility_build_controller != null:
		facility_build_controller.set_facility_build_enabled(
			false
		)

	current_mode = new_mode

	match current_mode:
		EditMode.NONE:
			_enter_gameplay_mode()

		EditMode.FACILITY_BUILD:
			_enter_facility_build_mode()

		EditMode.ROOM_LAYOUT:
			_enter_room_layout_mode()

	edit_mode_changed.emit(
		current_mode
	)


func get_mode() -> int:
	return current_mode


func is_facility_build_mode() -> bool:
	return (
		current_mode
		== EditMode.FACILITY_BUILD
	)


func is_room_layout_mode() -> bool:
	return (
		current_mode
		== EditMode.ROOM_LAYOUT
	)


# ============================================================
# Mode Switching
# ============================================================


func _toggle_mode(
	requested_mode: int
) -> void:
	if current_mode == requested_mode:
		set_mode(
			EditMode.NONE
		)
	else:
		set_mode(
			requested_mode
		)


func _enter_gameplay_mode() -> void:
	_set_player_frozen(
		false
	)

	if gameplay_camera != null:
		gameplay_camera.set_camera_mode(
			ShelterCamera.CameraMode.GAMEPLAY
		)

	print(
		"[ShelterEditMode] GAMEPLAY"
	)


func _enter_facility_build_mode() -> void:
	_set_player_frozen(
		true
	)

	if gameplay_camera != null:
		gameplay_camera.set_camera_mode(
			ShelterCamera.CameraMode.FACILITY_BUILD
		)

	if facility_build_controller != null:
		facility_build_controller.set_facility_build_enabled(
			true
		)

	print(
		"[ShelterEditMode] FACILITY BUILD"
	)

	if gameplay_camera != null:
		gameplay_camera.set_camera_mode(
			ShelterCamera.CameraMode.FACILITY_BUILD
		)

	print(
		"[ShelterEditMode] FACILITY BUILD"
	)


func _enter_room_layout_mode() -> void:
	_set_player_frozen(
		true
	)

	if gameplay_camera != null:
		gameplay_camera.set_camera_mode(
			ShelterCamera.CameraMode.ROOM_LAYOUT
		)

	if room_build_controller != null:
		room_build_controller.set_room_layout_enabled(
			true
		)

	print(
		"[ShelterEditMode] ROOM LAYOUT"
	)


# ============================================================
# Player
# ============================================================


func _set_player_frozen(
	frozen: bool
) -> void:
	if player == null:
		return

	if frozen:
		player.velocity = Vector3.ZERO

		player.set_physics_process(
			false
		)

		if (
			player.animation_player != null
			and player.animation_player.has_animation(
				player.idle_animation
			)
		):
			player.animation_player.play(
				player.idle_animation,
				player.animation_blend_time
			)

	else:
		player.set_physics_process(
			true
		)


# ============================================================
# Input Utility
# ============================================================


func _is_left_ctrl(
	event: InputEventKey
) -> bool:
	if event.keycode != KEY_CTRL:
		return false

	# 明确是右 Ctrl 时拒绝。
	if (
		event.location
		== KEY_LOCATION_RIGHT
	):
		return false

	# LEFT 或某些平台返回的 UNSPECIFIED
	# 都按左 Ctrl 处理。
	return true
