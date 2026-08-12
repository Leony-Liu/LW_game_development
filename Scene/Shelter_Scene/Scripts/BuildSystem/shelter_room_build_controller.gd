extends Node
class_name ShelterRoomBuildController


# ============================================================
# Shelter Room Build Controller
# ============================================================
#
# 当前阶段：
#
# Left Ctrl
#     进入 / 退出基地建造模式
#
# 1
#     Small 1x1
#
# 2
#     Medium 2x1
#
# 3
#     Large 2x2
#
# R
#     Medium 旋转
#
# Left Mouse
#     放置 Ghost
#     或选择已有房间
#
# Right Mouse
#     取消当前 Ghost
#     或取消房间选择
#
# G
#     移动当前选中的已有房间
#
# Delete
#     删除当前选中的已有房间
#
# Escape
#     取消当前操作
#
#
# 这些数字键/G/Delete 都是开发阶段临时操作。
# 后续会被正式 Shelter Build UI 替换。
# ============================================================


enum PlacementMode {
	NONE,
	NEW_ROOM,
	MOVE_ROOM
}


const ROOM_SMALL: int = 0
const ROOM_MEDIUM: int = 1
const ROOM_LARGE: int = 2


@export_category("References")

@export var room_manager: ShelterRoomManager



@export var gameplay_camera: ShelterCamera


@export_category("Build Zone")

## 初始房东侧就是 Road。
##
## 默认 Initial Room 位于 X Cell = 0，
## 因此任何新房间都不能占据 X > 0 的格子。
@export var restrict_building_to_initial_left_side: bool = true


@export_category("Ghost")

@export_range(0.01, 0.3, 0.01)
var ghost_height: float = 0.08

@export_range(0.0, 1.0, 0.05)
var ghost_alpha: float = 0.4


var build_mode_enabled: bool = false

var placement_mode: int = PlacementMode.NONE

var selected_room_id: int = -1

var moving_room_id: int = -1

var pending_room_type: int = ROOM_SMALL

var pending_rotated: bool = false

var pending_origin: Vector2i = Vector2i.ZERO

var _ghost_valid: bool = false


var _ghost: MeshInstance3D

var _selection_marker: MeshInstance3D

var _valid_material: StandardMaterial3D

var _invalid_material: StandardMaterial3D

var _selection_material: StandardMaterial3D


func _ready() -> void:
	_create_materials()
	_create_preview_nodes()

	_validate_setup()


func _process(_delta: float) -> void:
	if not build_mode_enabled:
		return

	if placement_mode == PlacementMode.NONE:
		return

	_update_placement_preview()


func _unhandled_input(
	event: InputEvent
) -> void:
	# RoomBuildController 本身不再负责进入模式。
	#
	# 只有 ShelterEditModeController
	# 开启 ROOM_LAYOUT 后，
	# 这里才接受房间编辑输入。

	if not build_mode_enabled:
		return

	# --------------------------------------------------------
	# Keyboard
	# --------------------------------------------------------

	if event is InputEventKey:
		var key_event := (
			event as InputEventKey
		)

		if not key_event.pressed:
			return

		if key_event.echo:
			return

		match key_event.keycode:
			KEY_1:
				_start_new_room(
					ROOM_SMALL
				)

			KEY_2:
				_start_new_room(
					ROOM_MEDIUM
				)

			KEY_3:
				_start_new_room(
					ROOM_LARGE
				)

			KEY_R:
				_rotate_pending_room()

			KEY_G:
				_start_moving_selected_room()

			KEY_DELETE:
				_delete_selected_room()

			KEY_ESCAPE:
				if (
					placement_mode
					!= PlacementMode.NONE
				):
					_cancel_placement()
				else:
					_clear_selection()

			_:
				return

		get_viewport().set_input_as_handled()
		return

	# --------------------------------------------------------
	# Mouse
	# --------------------------------------------------------

	if not event is InputEventMouseButton:
		return

	var mouse_event := (
		event as InputEventMouseButton
	)

	if not mouse_event.pressed:
		return

	match mouse_event.button_index:
		MOUSE_BUTTON_LEFT:
			if (
				placement_mode
				!= PlacementMode.NONE
			):
				_confirm_placement()
			else:
				_select_room_under_mouse()

			get_viewport().set_input_as_handled()

		MOUSE_BUTTON_RIGHT:
			if (
				placement_mode
				!= PlacementMode.NONE
			):
				_cancel_placement()
			else:
				_clear_selection()

			get_viewport().set_input_as_handled()

	# --------------------------------------------------------
	# Mouse
	# --------------------------------------------------------

	if not build_mode_enabled:
		return

	if not event is InputEventMouseButton:
		return


	if not mouse_event.pressed:
		return

	match mouse_event.button_index:
		MOUSE_BUTTON_LEFT:
			if (
				placement_mode
				!= PlacementMode.NONE
			):
				_confirm_placement()
			else:
				_select_room_under_mouse()

			get_viewport().set_input_as_handled()

		MOUSE_BUTTON_RIGHT:
			if (
				placement_mode
				!= PlacementMode.NONE
			):
				_cancel_placement()
			else:
				_clear_selection()

			get_viewport().set_input_as_handled()


# ============================================================
# Build Mode
# ============================================================


func _toggle_build_mode() -> void:
	set_build_mode(
		not build_mode_enabled
	)

func set_room_layout_enabled(
	enabled: bool
) -> void:
	set_build_mode(
		enabled
	)

func set_build_mode(
	enabled: bool
) -> void:
	if build_mode_enabled == enabled:
		return

	build_mode_enabled = enabled

	if build_mode_enabled:
		_enter_build_mode()
	else:
		_exit_build_mode()


func _enter_build_mode() -> void:
	print(
		"[ShelterRoomBuild] ROOM EDIT ENABLED"
	)

	print(
		"1 Small | 2 Medium | 3 Large"
	)

	print(
		"R Rotate | G Move | Delete Remove"
	)


func _exit_build_mode() -> void:
	_cancel_placement()
	_clear_selection()

	print(
		"[ShelterRoomBuild] ROOM EDIT DISABLED"
	)


# ============================================================
# New Room
# ============================================================


func _start_new_room(
	room_type: int
) -> void:
	_cancel_placement()
	_clear_selection()

	pending_room_type = room_type
	pending_rotated = false

	placement_mode = (
		PlacementMode.NEW_ROOM
	)

	_ghost.visible = true

	_refresh_ghost_shape()

	print(
		"[ShelterBuild] New Room: %s"
		% _get_room_type_name(
			room_type
		)
	)


# ============================================================
# Existing Room Selection
# ============================================================


func _select_room_under_mouse() -> void:
	var ground_point = (
		_get_mouse_ground_point()
	)

	if ground_point == null:
		_clear_selection()
		return

	var world_point: Vector3 = (
		ground_point
	)

	var cell := _world_to_cell(
		world_point
	)

	var room_id := (
		room_manager.get_room_id_at_cell(
			cell
		)
	)

	if room_id < 0:
		_clear_selection()
		return

	selected_room_id = room_id

	_refresh_selection_marker()

	print(
		"[ShelterBuild] Selected Room: %d"
		% selected_room_id
	)


func _clear_selection() -> void:
	selected_room_id = -1

	if _selection_marker != null:
		_selection_marker.visible = false


# ============================================================
# Move Existing Room
# ============================================================


func _start_moving_selected_room() -> void:
	if selected_room_id < 0:
		return

	var room := room_manager.get_room(
		selected_room_id
	)

	if room == null:
		return

	if room.locked:
		push_warning(
			"ShelterBuild: 初始房间不能移动。"
		)
		return

	_cancel_placement()

	moving_room_id = selected_room_id

	pending_room_type = room.room_type

	pending_rotated = room.rotated

	placement_mode = (
		PlacementMode.MOVE_ROOM
	)

	# 移动时隐藏原房间。
	#
	# GeneratedWalls 会暂时保留原状态，
	# 确认后 RoomManager 会统一重建。
	room.visible = false

	_selection_marker.visible = false
	_ghost.visible = true

	_refresh_ghost_shape()

	print(
		"[ShelterBuild] Moving Room: %d"
		% moving_room_id
	)


# ============================================================
# Delete
# ============================================================


func _delete_selected_room() -> void:
	if selected_room_id < 0:
		return

	var room := room_manager.get_room(
		selected_room_id
	)

	if room == null:
		_clear_selection()
		return

	if room.locked:
		push_warning(
			"ShelterBuild: 初始房间不能删除。"
		)
		return

	var removed := (
		room_manager.remove_room(
			selected_room_id
		)
	)

	if not removed:
		push_warning(
			"ShelterBuild: 无法删除该房间。"
			+ " 删除后会导致基地断开。"
		)
		return

	print(
		"[ShelterBuild] Removed Room: %d"
		% selected_room_id
	)

	_clear_selection()


# ============================================================
# Rotation
# ============================================================


func _rotate_pending_room() -> void:
	if (
		placement_mode
		== PlacementMode.NONE
	):
		return

	# 只有 Medium 可以旋转。
	if pending_room_type != ROOM_MEDIUM:
		return

	pending_rotated = (
		not pending_rotated
	)

	_refresh_ghost_shape()

	print(
		"[ShelterBuild] Medium Rotation: %s"
		% (
			"1x2"
			if pending_rotated
			else "2x1"
		)
	)


# ============================================================
# Preview
# ============================================================


func _update_placement_preview() -> void:
	var ground_point = (
		_get_mouse_ground_point()
	)

	if ground_point == null:
		_ghost.visible = false
		_ghost_valid = false
		return

	_ghost.visible = true

	var world_point: Vector3 = (
		ground_point
	)

	pending_origin = _world_to_cell(
		world_point
	)

	var footprint := (
		room_manager.get_room_footprint(
			pending_room_type,
			pending_rotated
		)
	)

	_update_ghost_transform(
		pending_origin,
		footprint
	)

	var ignore_room_id := -1

	if (
		placement_mode
		== PlacementMode.MOVE_ROOM
	):
		ignore_room_id = moving_room_id

	_ghost_valid = (
		_is_inside_build_zone(
			pending_origin,
			footprint
		)
		and room_manager.can_place_room(
			pending_origin,
			footprint,
			ignore_room_id
		)
	)

	if _ghost_valid:
		_ghost.material_override = (
			_valid_material
		)
	else:
		_ghost.material_override = (
			_invalid_material
		)


func _refresh_ghost_shape() -> void:
	var footprint = (
		room_manager.get_room_footprint(
			pending_room_type,
			pending_rotated
		)
	)

	var mesh := BoxMesh.new()

	mesh.size = Vector3(
		float(footprint.x)
		* room_manager.cell_size
		- 0.12,
		ghost_height,
		float(footprint.y)
		* room_manager.cell_size
		- 0.12
	)

	_ghost.mesh = mesh


func _update_ghost_transform(
	origin: Vector2i,
	footprint: Vector2i
) -> void:
	var local_center := (
		_get_room_local_center(
			origin,
			footprint
		)
	)

	var world_center := (
		room_manager.to_global(
			local_center
		)
	)

	world_center.y += (
		ghost_height * 0.5
		+ 0.01
	)

	_ghost.global_position = (
		world_center
	)


# ============================================================
# Confirm / Cancel
# ============================================================


func _confirm_placement() -> void:
	if not _ghost_valid:
		push_warning(
			"ShelterBuild: 当前房间位置非法。"
		)
		return

	match placement_mode:
		PlacementMode.NEW_ROOM:
			var new_room_id := (
				room_manager.add_room(
					pending_room_type,
					pending_origin,
					pending_rotated
				)
			)

			if new_room_id < 0:
				push_warning(
					"ShelterBuild: 房间创建失败。"
				)
				return

			print(
				"[ShelterBuild] Room Created: %d"
				% new_room_id
			)

			_cancel_placement()

			selected_room_id = new_room_id
			_refresh_selection_marker()

		PlacementMode.MOVE_ROOM:
			var room := room_manager.get_room(
				moving_room_id
			)

			if room == null:
				_cancel_placement()
				return

			# 先恢复可见。
			room.visible = true

			var moved := (
				room_manager.move_room(
					moving_room_id,
					pending_origin,
					pending_rotated
				)
			)

			if not moved:
				room.visible = false

				push_warning(
					"ShelterBuild: 房间移动失败。"
				)
				return

			var moved_id := moving_room_id

			_cancel_placement()

			selected_room_id = moved_id

			_refresh_selection_marker()

			print(
				"[ShelterBuild] Room Moved: %d"
				% moved_id
			)


func _cancel_placement() -> void:
	# 如果正在移动旧房间，
	# 取消时恢复原房间。
	if (
		placement_mode
		== PlacementMode.MOVE_ROOM
		and moving_room_id >= 0
	):
		var room := room_manager.get_room(
			moving_room_id
		)

		if room != null:
			room.visible = true

	placement_mode = (
		PlacementMode.NONE
	)

	moving_room_id = -1

	_ghost_valid = false

	if _ghost != null:
		_ghost.visible = false


# ============================================================
# Build Zone
# ============================================================


func _is_inside_build_zone(
	origin: Vector2i,
	footprint: Vector2i
) -> bool:
	if not restrict_building_to_initial_left_side:
		return true

	# 初始房的 X Cell 是基地最东边合法列。
	#
	# 初始房东侧完全留给：
	# Road / NPC / Raid Entrance
	var max_build_x := (
		room_manager.initial_room_origin.x
	)

	for x in range(footprint.x):
		for z in range(footprint.y):
			var cell := (
				origin
				+ Vector2i(x, z)
			)

			if cell.x > max_build_x:
				return false

	return true


# ============================================================
# Mouse -> Ground -> Grid
# ============================================================


func _get_mouse_ground_point() -> Variant:
	if gameplay_camera == null:
		return null

	var mouse_position := (
		get_viewport().get_mouse_position()
	)

	var ray_origin := (
		gameplay_camera.project_ray_origin(
			mouse_position
		)
	)

	var ray_direction := (
		gameplay_camera.project_ray_normal(
			mouse_position
		)
	)

	# 所有房间当前都位于 Y = 0。
	var ground_plane := Plane(
		Vector3.UP,
		0.0
	)

	return ground_plane.intersects_ray(
		ray_origin,
		ray_direction
	)


func _world_to_cell(
	world_position: Vector3
) -> Vector2i:
	var local_position := (
		room_manager.to_local(
			world_position
		)
	)

	return Vector2i(
		int(
			round(
				local_position.x
				/ room_manager.cell_size
			)
		),
		int(
			round(
				local_position.z
				/ room_manager.cell_size
			)
		)
	)


func _get_room_local_center(
	origin: Vector2i,
	footprint: Vector2i
) -> Vector3:
	var center_x := (
		float(origin.x)
		+ float(
			footprint.x - 1
		) * 0.5
	) * room_manager.cell_size

	var center_z := (
		float(origin.y)
		+ float(
			footprint.y - 1
		) * 0.5
	) * room_manager.cell_size

	return Vector3(
		center_x,
		0.0,
		center_z
	)


# ============================================================
# Selection Visual
# ============================================================


func _refresh_selection_marker() -> void:
	if selected_room_id < 0:
		_selection_marker.visible = false
		return

	var room := room_manager.get_room(
		selected_room_id
	)

	if room == null:
		_selection_marker.visible = false
		return

	var mesh := BoxMesh.new()

	mesh.size = Vector3(
		float(room.footprint.x)
		* room_manager.cell_size
		- 0.25,
		0.05,
		float(room.footprint.y)
		* room_manager.cell_size
		- 0.25
	)

	_selection_marker.mesh = mesh

	var local_center := (
		_get_room_local_center(
			room.origin_cell,
			room.footprint
		)
	)

	var world_center := (
		room_manager.to_global(
			local_center
		)
	)

	world_center.y += 0.035

	_selection_marker.global_position = (
		world_center
	)

	_selection_marker.visible = true


# ============================================================
# Visual Setup
# ============================================================


func _create_preview_nodes() -> void:
	_ghost = MeshInstance3D.new()
	_ghost.name = "RoomGhost"
	_ghost.visible = false

	add_child(_ghost)

	_selection_marker = (
		MeshInstance3D.new()
	)

	_selection_marker.name = (
		"RoomSelectionMarker"
	)

	_selection_marker.material_override = (
		_selection_material
	)

	_selection_marker.visible = false

	add_child(_selection_marker)


func _create_materials() -> void:
	_valid_material = (
		_create_transparent_material(
			Color(
				0.15,
				0.95,
				0.35,
				ghost_alpha
			)
		)
	)

	_invalid_material = (
		_create_transparent_material(
			Color(
				1.0,
				0.15,
				0.15,
				ghost_alpha
			)
		)
	)

	_selection_material = (
		_create_transparent_material(
			Color(
				0.15,
				0.65,
				1.0,
				0.25
			)
		)
	)


func _create_transparent_material(
	color: Color
) -> StandardMaterial3D:
	var material := (
		StandardMaterial3D.new()
	)

	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)

	material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)

	material.albedo_color = color

	return material


# ============================================================
# Utility
# ============================================================


func _get_room_type_name(
	room_type: int
) -> String:
	match room_type:
		ROOM_SMALL:
			return "SMALL 1x1"

		ROOM_MEDIUM:
			return "MEDIUM"

		ROOM_LARGE:
			return "LARGE 2x2"

	return "UNKNOWN"


func _validate_setup() -> void:
	if room_manager == null:
		push_error(
			"ShelterBuild: RoomManager 未设置。"
		)



	if gameplay_camera == null:
		push_error(
			"ShelterBuild: Gameplay Camera 未设置。"
		)
