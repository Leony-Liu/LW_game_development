extends Node
class_name ShelterFacilityBuildController

signal facility_changed

enum DragMode {
	NONE,
	X_AXIS,
	Z_AXIS,
	XZ_PLANE,
	Y_ROTATION
}


@export_category("References")

@export var room_manager: ShelterRoomManager

@export var gameplay_camera: ShelterCamera

@export var player: ShelterPlayer


@export_category("Debug Facility")

@export var test_facility_scene: PackedScene


@export_category("Placement")

@export_range(0.001, 0.05, 0.001)
var collision_floor_epsilon: float = 0.01

@export_range(0.0, 0.1, 0.001)
var boundary_epsilon: float = 0.01

@export_category("Rotation")

## 设施模型自身的“正面”方向补偿。
##
## 0：
## 模型本地 +Z 朝向鼠标。
##
## 180：
## 如果模型本地 -Z 才是正面。
##
## 90 / -90：
## 如果模型正面位于本地 X 轴方向。
@export_range(-180.0, 180.0, 1.0)
var rotation_facing_offset_degrees: float = 0.0

var facility_build_enabled: bool = false

var current_room: ShelterRoom

var current_room_id: int = -1


var _ghost: ShelterFacility

var _ghost_valid: bool = false


var _gizmo: ShelterFacilityGizmo


var _drag_mode: int = DragMode.NONE

var _drag_start_point: Vector3 = Vector3.ZERO

var _drag_start_position: Vector3 = Vector3.ZERO


var _valid_material: StandardMaterial3D

var _invalid_material: StandardMaterial3D


func _ready() -> void:
	_create_preview_materials()
	_create_gizmo()


func _process(_delta: float) -> void:
	if not facility_build_enabled:
		return

	if _ghost == null:
		return

	_update_gizmo_mode()
	_update_gizmo_transform()

	if _drag_mode != DragMode.NONE:
		_update_active_drag()

	_update_ghost_validity()


func _unhandled_input(
	event: InputEvent
) -> void:
	if not facility_build_enabled:
		return

	# --------------------------------------------------------
	# Enter
	# --------------------------------------------------------

	if event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed:
			return

		if key_event.echo:
			return

		if key_event.keycode == KEY_ENTER:
			_confirm_placement()

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

	if (
		mouse_event.button_index
		!= MOUSE_BUTTON_LEFT
	):
		return

	if mouse_event.pressed:
		_begin_gizmo_drag()
	else:
		_end_gizmo_drag()

	get_viewport().set_input_as_handled()


# ============================================================
# Public API
# ============================================================


func set_facility_build_enabled(
	enabled: bool
) -> void:
	if facility_build_enabled == enabled:
		return

	facility_build_enabled = enabled

	if facility_build_enabled:
		_enter_facility_build()
	else:
		_exit_facility_build()


# ============================================================
# Mode
# ============================================================


func _enter_facility_build() -> void:
	current_room = _find_player_room()

	if current_room == null:
		current_room_id = -1

		push_warning(
			"ShelterFacilityBuild: "
			+ "玩家当前不在任何可建造房间内。"
		)

		return

	current_room_id = current_room.room_id

	print(
		"[ShelterFacilityBuild] Current Room: %d"
		% current_room_id
	)

	_spawn_test_ghost()


func _exit_facility_build() -> void:
	_end_gizmo_drag()

	_clear_ghost()

	current_room = null
	current_room_id = -1

	if _gizmo != null:
		_gizmo.visible = false

	print(
		"[ShelterFacilityBuild] DISABLED"
	)


# ============================================================
# Current Room
# ============================================================


func _find_player_room() -> ShelterRoom:
	if room_manager == null:
		push_error(
			"ShelterFacilityBuild: "
			+ "RoomManager 未设置。"
		)

		return null

	if player == null:
		push_error(
			"ShelterFacilityBuild: "
			+ "Player 未设置。"
		)

		return null

	var local_position := (
		room_manager.to_local(
			player.global_position
		)
	)

	var cell := Vector2i(
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

	var room_id := (
		room_manager.get_room_id_at_cell(
			cell
		)
	)

	if room_id < 0:
		return null

	return room_manager.get_room(
		room_id
	)


# ============================================================
# Ghost
# ============================================================


func _spawn_test_ghost() -> void:
	_clear_ghost()

	if current_room == null:
		return

	if test_facility_scene == null:
		push_error(
			"ShelterFacilityBuild: "
			+ "Test Facility Scene 未设置。"
		)

		return

	var instance := (
		test_facility_scene.instantiate()
	)

	if not instance is ShelterFacility:
		push_error(
			"ShelterFacilityBuild: "
			+ "测试设施根节点必须使用 "
			+ "ShelterFacility 脚本。"
		)

		instance.queue_free()
		return

	_ghost = instance as ShelterFacility
	_ghost.name = "FacilityGhost"

	add_child(
		_ghost
	)

	_disable_ghost_collision(
		_ghost
	)

	var room_center := (
		current_room.global_position
	)

	_ghost.global_position = Vector3(
		room_center.x,
		room_center.y,
		room_center.z
	)

	_ghost.global_rotation = Vector3.ZERO

	_drag_mode = DragMode.NONE

	if _gizmo != null:
		_gizmo.visible = true

		_gizmo.set_rotation_mode(
			false
		)

		_gizmo.sync_to_facility(
			_ghost
		)

	_update_ghost_validity()


func _clear_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()

	_ghost = null
	_ghost_valid = false

	if _gizmo != null:
		_gizmo.visible = false


func _disable_ghost_collision(
	node: Node
) -> void:
	if node is CollisionShape3D:
		var collision := (
			node as CollisionShape3D
		)

		collision.disabled = true

	for child in node.get_children():
		_disable_ghost_collision(
			child
		)


# ============================================================
# Gizmo Setup
# ============================================================


func _create_gizmo() -> void:
	_gizmo = ShelterFacilityGizmo.new()

	_gizmo.name = "FacilityGizmo"

	add_child(
		_gizmo
	)

	_gizmo.visible = false


func _update_gizmo_transform() -> void:
	if _gizmo == null:
		return

	if _ghost == null:
		_gizmo.visible = false
		return

	_gizmo.sync_to_facility(
		_ghost
	)


func _update_gizmo_mode() -> void:
	if _gizmo == null:
		return

	# 拖动已经开始后，
	# 不允许中途通过 Shift 改变 Drag 类型。
	if _drag_mode != DragMode.NONE:
		return

	var rotation_requested := (
		Input.is_physical_key_pressed(
			KEY_SHIFT
		)
	)

	_gizmo.set_rotation_mode(
		rotation_requested
	)


# ============================================================
# Gizmo Drag Begin
# ============================================================


func _begin_gizmo_drag() -> void:
	if _ghost == null:
		return

	if _gizmo == null:
		return

	var plane_point = (
		_get_mouse_gizmo_plane_point()
	)

	if plane_point == null:
		return

	var world_point := (
		plane_point as Vector3
	)

	var handle := _gizmo.pick_handle(
		world_point
	)

	match handle:
		ShelterFacilityGizmo.Handle.X_AXIS:
			_begin_translation_drag(
				DragMode.X_AXIS,
				world_point
			)

		ShelterFacilityGizmo.Handle.Z_AXIS:
			_begin_translation_drag(
				DragMode.Z_AXIS,
				world_point
			)

		ShelterFacilityGizmo.Handle.XZ_PLANE:
			_begin_translation_drag(
				DragMode.XZ_PLANE,
				world_point
			)

		ShelterFacilityGizmo.Handle.Y_ROTATION:
			_begin_rotation_drag(
				world_point
			)

		_:
			return


func _begin_translation_drag(
	mode: int,
	world_point: Vector3
) -> void:
	_drag_mode = mode

	_drag_start_point = world_point

	_drag_start_position = (
		_ghost.global_position
	)


func _begin_rotation_drag(
	world_point: Vector3
) -> void:
	if _ghost == null:
		return

	var center := (
		_ghost.global_position
	)

	var direction := Vector2(
		world_point.x - center.x,
		world_point.z - center.z
	)

	if direction.length_squared() < 0.0001:
		return

	_drag_mode = (
		DragMode.Y_ROTATION
	)

	# 点击旋转环后立即同步一次朝向。
	_set_ghost_facing_mouse_point(
		world_point
	)


func _end_gizmo_drag() -> void:
	_drag_mode = DragMode.NONE


# ============================================================
# Active Drag
# ============================================================


func _update_active_drag() -> void:
	match _drag_mode:
		DragMode.X_AXIS:
			_update_translation_drag_x()

		DragMode.Z_AXIS:
			_update_translation_drag_z()

		DragMode.XZ_PLANE:
			_update_translation_drag_xz()

		DragMode.Y_ROTATION:
			_update_rotation_drag()


# ============================================================
# Translation
# ============================================================


func _update_translation_drag_x() -> void:
	var plane_point = (
		_get_mouse_gizmo_plane_point()
	)

	if plane_point == null:
		return

	var current := (
		plane_point as Vector3
	)

	var delta_x := (
		current.x
		- _drag_start_point.x
	)

	_ghost.global_position = Vector3(
		_drag_start_position.x + delta_x,
		current_room.global_position.y,
		_drag_start_position.z
	)


func _update_translation_drag_z() -> void:
	var plane_point = (
		_get_mouse_gizmo_plane_point()
	)

	if plane_point == null:
		return

	var current := (
		plane_point as Vector3
	)

	var delta_z := (
		current.z
		- _drag_start_point.z
	)

	_ghost.global_position = Vector3(
		_drag_start_position.x,
		current_room.global_position.y,
		_drag_start_position.z + delta_z
	)


func _update_translation_drag_xz() -> void:
	var plane_point = (
		_get_mouse_gizmo_plane_point()
	)

	if plane_point == null:
		return

	var current := (
		plane_point as Vector3
	)

	var delta := (
		current
		- _drag_start_point
	)

	_ghost.global_position = Vector3(
		_drag_start_position.x + delta.x,
		current_room.global_position.y,
		_drag_start_position.z + delta.z
	)


# ============================================================
# Rotation
# ============================================================


func _update_rotation_drag() -> void:
	var plane_point = (
		_get_mouse_gizmo_plane_point()
	)

	if plane_point == null:
		return

	var current := (
		plane_point as Vector3
	)

	_set_ghost_facing_mouse_point(
		current
	)

func _set_ghost_facing_mouse_point(
	world_point: Vector3
) -> void:
	if _ghost == null:
		return

	var center := (
		_ghost.global_position
	)

	var direction := Vector2(
		world_point.x - center.x,
		world_point.z - center.z
	)

	if direction.length_squared() < 0.0001:
		return

	# --------------------------------------------------------
	# Mouse Facing Rotation
	# --------------------------------------------------------
	#
	# XZ 平面：
	#
	#           -Z
	#            ↑
	#
	#     -X ← Ghost → +X
	#
	#            ↓
	#           +Z
	#
	#
	# atan2(
	#     direction.x,
	#     direction.y
	# )
	#
	# 会让设施的本地 +Z
	# 朝向鼠标所在方向。
	# --------------------------------------------------------

	var target_yaw := atan2(
		direction.x,
		direction.y
	)

	target_yaw += deg_to_rad(
		rotation_facing_offset_degrees
	)

	var current_rotation := (
		_ghost.global_rotation
	)

	current_rotation.y = target_yaw

	_ghost.global_rotation = (
		current_rotation
	)

# ============================================================
# Mouse Ray
# ============================================================


func _get_mouse_gizmo_plane_point() -> Variant:
	if gameplay_camera == null:
		return null

	if _gizmo == null:
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

	var gizmo_plane := Plane(
		Vector3.UP,
		_gizmo.get_gizmo_plane_height()
	)

	return gizmo_plane.intersects_ray(
		ray_origin,
		ray_direction
	)


# ============================================================
# Placement Validation
# ============================================================


func _update_ghost_validity() -> void:
	if _ghost == null:
		_ghost_valid = false
		return

	_ghost_valid = (
		_is_inside_current_room()
		and not _is_overlapping_obstacle()
	)

	if _ghost_valid:
		_apply_ghost_material(
			_valid_material
		)
	else:
		_apply_ghost_material(
			_invalid_material
		)


func _is_inside_current_room() -> bool:
	if current_room == null:
		return false

	if _ghost == null:
		return false

	var facility_size := (
		_ghost.placement_size
	)

	var half_x := (
		facility_size.x * 0.5
	)

	var half_z := (
		facility_size.z * 0.5
	)

	var room_half_x := (
		float(current_room.footprint.x)
		* current_room.cell_size
		* 0.5
	)

	var room_half_z := (
		float(current_room.footprint.y)
		* current_room.cell_size
		* 0.5
	)

	var room_center := (
		current_room.global_position
	)

	var rotation_basis := Basis(
		Vector3.UP,
		_ghost.global_rotation.y
	)

	var corners: Array[Vector3] = [
		Vector3(
			-half_x,
			0.0,
			-half_z
		),
		Vector3(
			half_x,
			0.0,
			-half_z
		),
		Vector3(
			half_x,
			0.0,
			half_z
		),
		Vector3(
			-half_x,
			0.0,
			half_z
		)
	]

	for corner in corners:
		var rotated_corner := (
			rotation_basis * corner
		)

		var world_corner := (
			_ghost.global_position
			+ rotated_corner
		)

		var relative_x := (
			world_corner.x
			- room_center.x
		)

		var relative_z := (
			world_corner.z
			- room_center.z
		)

		if (
			absf(relative_x)
			> room_half_x
			- boundary_epsilon
		):
			return false

		if (
			absf(relative_z)
			> room_half_z
			- boundary_epsilon
		):
			return false

	return true


func _is_overlapping_obstacle() -> bool:
	if _ghost == null:
		return true

	var world := (
		get_viewport().world_3d
	)

	if world == null:
		return true

	var space_state := (
		world.direct_space_state
	)

	var query_shape := BoxShape3D.new()

	query_shape.size = Vector3(
		maxf(
			_ghost.placement_size.x
			- 0.01,
			0.01
		),
		maxf(
			_ghost.placement_size.y
			- 0.01,
			0.01
		),
		maxf(
			_ghost.placement_size.z
			- 0.01,
			0.01
		)
	)

	var query := (
		PhysicsShapeQueryParameters3D.new()
	)

	query.shape = query_shape

	query.collide_with_bodies = true
	query.collide_with_areas = true

	query.collision_mask = 1

	var query_transform := (
		_ghost.global_transform
	)

	query_transform.origin.y += (
		_ghost.placement_size.y * 0.5
		+ collision_floor_epsilon
	)

	query.transform = query_transform

	# 玩家不阻挡设施建造。
	if player is CollisionObject3D:
		query.exclude = [
			(player as CollisionObject3D).get_rid()
		]

	var hits := (
		space_state.intersect_shape(
			query,
			32
		)
	)

	return not hits.is_empty()


# ============================================================
# Confirm
# ============================================================


func _confirm_placement() -> void:
	if _ghost == null:
		return

	if current_room == null:
		return

	if _drag_mode != DragMode.NONE:
		return

	if not _ghost_valid:
		push_warning(
			"ShelterFacilityBuild: "
			+ "当前位置不能建造。"
		)

		return

	if test_facility_scene == null:
		return

	var instance := (
		test_facility_scene.instantiate()
	)

	if not instance is ShelterFacility:
		instance.queue_free()
		return

	var facility := (
		instance as ShelterFacility
	)

	current_room.facilities_root.add_child(
		facility
	)

	facility.global_transform = (
		_ghost.global_transform
	)

	facility.set_room_id(
		current_room_id
	)
	
	facility_changed.emit()

	print(
		"[ShelterFacilityBuild] "
		+ "Placed '%s' in Room %d"
		% [
			facility.facility_id,
			current_room_id
		]
	)

	_spawn_test_ghost()


# ============================================================
# Ghost Materials
# ============================================================


func _create_preview_materials() -> void:
	_valid_material = (
		_create_preview_material(
			Color(
				0.15,
				1.0,
				0.3,
				0.45
			)
		)
	)

	_invalid_material = (
		_create_preview_material(
			Color(
				1.0,
				0.15,
				0.15,
				0.45
			)
		)
	)


func _create_preview_material(
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


func _apply_ghost_material(
	material: Material
) -> void:
	if _ghost == null:
		return

	_apply_material_recursive(
		_ghost,
		material
	)


func _apply_material_recursive(
	node: Node,
	material: Material
) -> void:
	if node is MeshInstance3D:
		var mesh_instance := (
			node as MeshInstance3D
		)

		mesh_instance.material_override = (
			material
		)

	for child in node.get_children():
		_apply_material_recursive(
			child,
			material
		)
