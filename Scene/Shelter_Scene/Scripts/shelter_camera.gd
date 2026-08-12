extends Camera3D
class_name ShelterCamera


# ============================================================
# Shelter Camera
# ============================================================
#
# GAMEPLAY
#     正常跟随玩家
#
# FACILITY_BUILD
#     单个房间内部的设施建造模式
#     斜俯视透视相机
#
# ROOM_LAYOUT
#     整个基地的房间布局模式
#     Y轴正上方垂直俯视
#     正交相机
# ============================================================


enum CameraMode {
	GAMEPLAY,
	FACILITY_BUILD,
	ROOM_LAYOUT
}


@export_category("Target")

@export var target: Node3D


@export_category("Gameplay Camera")

@export var camera_offset: Vector3 = Vector3(
	5.0,
	5.0,
	7.0
)

@export var look_height: float = 1.2


@export_category("Facility Build Camera")

## 设施建造模式平移速度。
@export var facility_pan_speed: float = 8.0

## 1.0 = 当前 Gameplay 镜头距离。
@export_range(1.0, 3.0, 0.05)
var facility_zoom_min: float = 1.0

@export_range(1.0, 4.0, 0.05)
var facility_zoom_max: float = 2.4

@export_range(0.05, 0.5, 0.05)
var facility_zoom_step: float = 0.15


@export_category("Room Layout Camera")

## 房间布局模式的 WASD 平移速度。
@export var room_pan_speed: float = 12.0

## 正交 Camera 离基地平面的高度。
##
## 正交模式中高度不控制缩放，
## 这里只需要保证 Camera 在基地上方。
@export var room_camera_height: float = 30.0

## 最近：
## 大约观察一个 8x8 小房间。
@export_range(4.0, 30.0, 0.5)
var room_zoom_min: float = 8.0

## 最远：
## 完整观察一个 16x16 的 2x2 大房间，
## 并留一些屏幕边距。
@export_range(8.0, 50.0, 0.5)
var room_zoom_max: float = 20.0

## 进入房间布局模式时的默认范围。
@export_range(4.0, 50.0, 0.5)
var room_zoom_default: float = 18.0

## 每格鼠标滚轮改变多少正交 Size。
@export_range(0.25, 4.0, 0.25)
var room_zoom_step: float = 1.0


var camera_mode: int = CameraMode.GAMEPLAY


var _facility_focus: Vector3 = Vector3.ZERO
var _facility_zoom: float = 1.0


var _room_focus: Vector3 = Vector3.ZERO
var _room_zoom: float = 18.0


func _ready() -> void:
	make_current()

	if target == null:
		push_error(
			"ShelterCamera: Target 未设置。"
		)
		return

	set_camera_mode(
		CameraMode.GAMEPLAY
	)


func _physics_process(delta: float) -> void:
	if target == null:
		return

	match camera_mode:
		CameraMode.GAMEPLAY:
			_update_gameplay_transform()

		CameraMode.FACILITY_BUILD:
			_update_facility_pan(delta)
			_update_facility_transform()

		CameraMode.ROOM_LAYOUT:
			_update_room_pan(delta)
			_update_room_transform()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := (
		event as InputEventMouseButton
	)

	if not mouse_event.pressed:
		return

	match camera_mode:
		CameraMode.FACILITY_BUILD:
			_handle_facility_zoom(
				mouse_event
			)

		CameraMode.ROOM_LAYOUT:
			_handle_room_zoom(
				mouse_event
			)


# ============================================================
# Public API
# ============================================================


func set_camera_mode(
	new_mode: int
) -> void:
	if target == null:
		camera_mode = new_mode
		return

	camera_mode = new_mode

	match camera_mode:
		CameraMode.GAMEPLAY:
			_enter_gameplay_camera()

		CameraMode.FACILITY_BUILD:
			_enter_facility_camera()

		CameraMode.ROOM_LAYOUT:
			_enter_room_camera()


func get_camera_mode() -> int:
	return camera_mode


## 兼容上一阶段代码。
##
## 以后 set_build_mode() 代表设施建造视角。
func set_build_mode(
	enabled: bool
) -> void:
	if enabled:
		set_camera_mode(
			CameraMode.FACILITY_BUILD
		)
	else:
		set_camera_mode(
			CameraMode.GAMEPLAY
		)


# ============================================================
# Gameplay
# ============================================================


func _enter_gameplay_camera() -> void:
	projection = (
		Camera3D.PROJECTION_PERSPECTIVE
	)

	_update_gameplay_transform()


func _update_gameplay_transform() -> void:
	global_position = (
		target.global_position
		+ camera_offset
	)

	var look_target := (
		target.global_position
		+ Vector3.UP * look_height
	)

	look_at(
		look_target,
		Vector3.UP
	)


# ============================================================
# Facility Build Camera
# ============================================================


func _enter_facility_camera() -> void:
	projection = (
		Camera3D.PROJECTION_PERSPECTIVE
	)

	_facility_focus = (
		target.global_position
		+ Vector3.UP * look_height
	)

	_facility_zoom = (
		facility_zoom_min
	)

	_update_facility_transform()


func _update_facility_pan(
	delta: float
) -> void:
	var input_vector := Input.get_vector(
		"Left",
		"Right",
		"Up",
		"Down"
	)

	if input_vector.is_zero_approx():
		return

	var forward := -global_basis.z
	var right := global_basis.x

	forward.y = 0.0
	right.y = 0.0

	if not forward.is_zero_approx():
		forward = forward.normalized()

	if not right.is_zero_approx():
		right = right.normalized()

	var move_direction := (
		right * input_vector.x
		+ forward * -input_vector.y
	)

	if move_direction.length_squared() > 1.0:
		move_direction = (
			move_direction.normalized()
		)

	var effective_speed := (
		facility_pan_speed
		* _facility_zoom
	)

	_facility_focus += (
		move_direction
		* effective_speed
		* delta
	)

	_facility_focus.y = (
		target.global_position.y
		+ look_height
	)


func _update_facility_transform() -> void:
	global_position = (
		_facility_focus
		+ camera_offset * _facility_zoom
	)

	look_at(
		_facility_focus,
		Vector3.UP
	)


func _handle_facility_zoom(
	mouse_event: InputEventMouseButton
) -> void:
	if (
		mouse_event.button_index
		== MOUSE_BUTTON_WHEEL_UP
	):
		_facility_zoom -= (
			facility_zoom_step
		)

	elif (
		mouse_event.button_index
		== MOUSE_BUTTON_WHEEL_DOWN
	):
		_facility_zoom += (
			facility_zoom_step
		)

	else:
		return

	_facility_zoom = clampf(
		_facility_zoom,
		facility_zoom_min,
		facility_zoom_max
	)

	get_viewport().set_input_as_handled()


# ============================================================
# Room Layout Camera
# ============================================================


func _enter_room_camera() -> void:
	# 正交投影。
	projection = (
		Camera3D.PROJECTION_ORTHOGONAL
	)

	# 一开始以玩家所在位置为观察中心。
	_room_focus = Vector3(
		target.global_position.x,
		0.0,
		target.global_position.z
	)

	_room_zoom = clampf(
		room_zoom_default,
		room_zoom_min,
		room_zoom_max
	)

	size = _room_zoom

	_update_room_transform()


func _update_room_pan(
	delta: float
) -> void:
	var input_vector := Input.get_vector(
		"Left",
		"Right",
		"Up",
		"Down"
	)

	if input_vector.is_zero_approx():
		return

	# 房间布局模式完全按照世界坐标移动。
	#
	# A = -X
	# D = +X
	# W = -Z
	# S = +Z
	var move_direction := Vector3(
		input_vector.x,
		0.0,
		input_vector.y
	)

	if move_direction.length_squared() > 1.0:
		move_direction = (
			move_direction.normalized()
		)

	# 镜头拉得越远，
	# WASD 平移稍微加快。
	var zoom_ratio := (
		_room_zoom
		/ room_zoom_min
	)

	var effective_speed := (
		room_pan_speed
		* zoom_ratio
	)

	_room_focus += (
		move_direction
		* effective_speed
		* delta
	)

	_room_focus.y = 0.0


func _update_room_transform() -> void:
	global_position = Vector3(
		_room_focus.x,
		room_camera_height,
		_room_focus.z
	)

	# Camera 此时视线和世界 Y 轴平行。
	#
	# 因此不能使用 Vector3.UP 作为 look_at 的 up，
	# 否则观察方向和 up 会平行。
	#
	# 使用 -Z 作为画面顶部，
	# 所以 W 对应屏幕向上。
	look_at(
		_room_focus,
		Vector3.FORWARD
	)

	size = _room_zoom


func _handle_room_zoom(
	mouse_event: InputEventMouseButton
) -> void:
	if (
		mouse_event.button_index
		== MOUSE_BUTTON_WHEEL_UP
	):
		_room_zoom -= (
			room_zoom_step
		)

	elif (
		mouse_event.button_index
		== MOUSE_BUTTON_WHEEL_DOWN
	):
		_room_zoom += (
			room_zoom_step
		)

	else:
		return

	_room_zoom = clampf(
		_room_zoom,
		room_zoom_min,
		room_zoom_max
	)

	size = _room_zoom

	get_viewport().set_input_as_handled()
