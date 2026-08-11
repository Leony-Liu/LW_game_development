extends Node3D
class_name ShelterRoomManager


# ============================================================
# Shelter Room Manager
# ============================================================
#
# 基础网格：
# 1 Cell = 8m x 8m
#
# Small:
# 1 x 1
#
# Medium:
# 2 x 1
# 或
# 1 x 2
#
# Large:
# 2 x 2
#
#
# 重要：
#
# 房间只生成地板。
#
# 所有墙和门统一在这里根据全局占用情况生成，
# 从根本上避免两个房间之间生成两套墙的问题。
# ============================================================


signal room_added(room_id: int)
signal room_moved(room_id: int)
signal room_removed(room_id: int)

## 后期 Storage 系统接入点。
signal facility_storage_requested(facility: Node)


enum RoomType {
	SMALL,
	MEDIUM,
	LARGE
}


enum WallSide {
	NORTH,
	EAST,
	SOUTH,
	WEST
}


const DIRECTIONS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]


@export_category("Grid")

## 最小房间单元：
## 8m x 8m
@export var cell_size: float = 8.0


@export_category("Wall")

@export var wall_height: float = 2.8

@export var wall_thickness: float = 0.2

## 门固定宽度。
@export var door_width: float = 2.0


@export_category("Initial Room")

## 初始房间中心格。
@export var initial_room_origin: Vector2i = Vector2i.ZERO

## 初始房间通往 Road 的永久出口。
##
## North / East / South / West
@export_enum(
	"North",
	"East",
	"South",
	"West"
)
var initial_exit_side: int = WallSide.EAST


@export_category("Debug")

## 开启后会自动生成一组测试房间。
##
## 只用于验证：
## - 1x1
## - 2x1
## - 2x2
## - 多段接触生成多扇门
##
## 正式使用时关闭。
@export var debug_generate_sample_layout: bool = false


var rooms: Dictionary = {}

## Vector2i -> room_id
var occupied_cells: Dictionary = {}

var initial_room_id: int = 0

var _next_room_id: int = 1

var _rooms_root: Node3D
var _walls_root: Node3D
var _storage_placeholder: Node3D

var _wall_material: StandardMaterial3D


func _ready() -> void:
	_create_runtime_roots()
	_create_wall_material()

	_create_initial_room()

	if debug_generate_sample_layout:
		_create_debug_layout()

	_rebuild_all_walls()


# ============================================================
# Public API
# ============================================================


func add_room(
	room_type: int,
	origin: Vector2i,
	rotated: bool = false
) -> int:
	var footprint := get_room_footprint(
		room_type,
		rotated
	)

	if not can_place_room(
		origin,
		footprint
	):
		return -1

	var room_id := _next_room_id
	_next_room_id += 1

	var room := ShelterRoom.new()

	room.configure(
		room_id,
		room_type,
		origin,
		footprint,
		rotated,
		false,
		cell_size
	)

	_rooms_root.add_child(room)

	rooms[room_id] = room

	_register_room_cells(room)

	_rebuild_all_walls()

	room_added.emit(room_id)

	return room_id


func move_room(
	room_id: int,
	new_origin: Vector2i,
	new_rotated: bool
) -> bool:
	var room := get_room(room_id)

	if room == null:
		return false

	if room.locked:
		return false

	var new_footprint := get_room_footprint(
		room.room_type,
		new_rotated
	)

	if not can_place_room(
		new_origin,
		new_footprint,
		room_id
	):
		return false

	_unregister_room_cells(room)

	var should_rotate_contents := (
		room.room_type == RoomType.MEDIUM
		and room.rotated != new_rotated
	)

	room.set_layout(
		new_origin,
		new_footprint,
		new_rotated,
		should_rotate_contents
	)

	_register_room_cells(room)

	_rebuild_all_walls()

	room_moved.emit(room_id)

	return true


func can_remove_room(room_id: int) -> bool:
	var room := get_room(room_id)

	if room == null:
		return false

	if room.locked:
		return false

	var test_occupancy := _make_occupancy_without_room(
		room_id
	)

	return _all_cells_connected(
		test_occupancy
	)


func remove_room(room_id: int) -> bool:
	if not can_remove_room(room_id):
		return false

	var room := get_room(room_id)

	if room == null:
		return false

	_return_facilities_to_storage(room)

	_unregister_room_cells(room)

	rooms.erase(room_id)

	room.queue_free()

	_rebuild_all_walls()

	room_removed.emit(room_id)

	return true


func can_place_room(
	origin: Vector2i,
	footprint: Vector2i,
	ignore_room_id: int = -1
) -> bool:
	var test_occupancy := _make_occupancy_without_room(
		ignore_room_id
	)

	var candidate_cells: Array[Vector2i] = []

	for x in range(footprint.x):
		for z in range(footprint.y):
			var cell := (
				origin
				+ Vector2i(x, z)
			)

			if test_occupancy.has(cell):
				return false

			candidate_cells.append(cell)

	# 用负值作为临时候选房间 ID。
	for cell in candidate_cells:
		test_occupancy[cell] = -999

	# 初始房存在以后，
	# 所有新增 / 移动后的房间必须与整个基地保持连通。
	return _all_cells_connected(
		test_occupancy
	)


func get_room(room_id: int) -> ShelterRoom:
	if not rooms.has(room_id):
		return null

	return rooms[room_id] as ShelterRoom


func get_room_id_at_cell(
	cell: Vector2i
) -> int:
	if not occupied_cells.has(cell):
		return -1

	return int(
		occupied_cells[cell]
	)


func get_room_footprint(
	room_type: int,
	rotated: bool = false
) -> Vector2i:
	match room_type:
		RoomType.SMALL:
			return Vector2i(1, 1)

		RoomType.MEDIUM:
			if rotated:
				return Vector2i(1, 2)

			return Vector2i(2, 1)

		RoomType.LARGE:
			return Vector2i(2, 2)

	return Vector2i.ONE


func grid_cell_to_world(
	cell: Vector2i
) -> Vector3:
	return Vector3(
		float(cell.x) * cell_size,
		0.0,
		float(cell.y) * cell_size
	)


# ============================================================
# Initial Room
# ============================================================


func _create_initial_room() -> void:
	var room := ShelterRoom.new()

	room.configure(
		initial_room_id,
		RoomType.SMALL,
		initial_room_origin,
		Vector2i.ONE,
		false,
		true,
		cell_size
	)

	_rooms_root.add_child(room)

	rooms[initial_room_id] = room

	_register_room_cells(room)


# ============================================================
# Occupancy
# ============================================================


func _register_room_cells(
	room: ShelterRoom
) -> void:
	for cell in room.get_occupied_cells():
		occupied_cells[cell] = room.room_id


func _unregister_room_cells(
	room: ShelterRoom
) -> void:
	for cell in room.get_occupied_cells():
		if occupied_cells.has(cell):
			occupied_cells.erase(cell)


func _make_occupancy_without_room(
	ignored_room_id: int
) -> Dictionary:
	var result: Dictionary = {}

	for cell_variant in occupied_cells.keys():
		var cell := cell_variant as Vector2i
		var room_id := int(
			occupied_cells[cell]
		)

		if room_id == ignored_room_id:
			continue

		result[cell] = room_id

	return result


# ============================================================
# Connectivity
# ============================================================


func _all_cells_connected(
	test_occupancy: Dictionary
) -> bool:
	if test_occupancy.is_empty():
		return false

	if not test_occupancy.has(
		initial_room_origin
	):
		return false

	var visited: Dictionary = {}

	var queue: Array[Vector2i] = [
		initial_room_origin
	]

	var queue_index := 0

	while queue_index < queue.size():
		var current := queue[queue_index]
		queue_index += 1

		if visited.has(current):
			continue

		visited[current] = true

		for direction in DIRECTIONS:
			var neighbor: Vector2i = (
				current + direction
			)

			if not test_occupancy.has(
				neighbor
			):
				continue

			if visited.has(neighbor):
				continue

			queue.append(neighbor)

	return (
		visited.size()
		== test_occupancy.size()
	)


# ============================================================
# Wall Generation
# ============================================================


func _rebuild_all_walls() -> void:
	for child in _walls_root.get_children():
		child.free()

	for cell_variant in occupied_cells.keys():
		var cell := cell_variant as Vector2i

		var current_room_id := int(
			occupied_cells[cell]
		)

		for side in range(4):
			var direction: Vector2i = (
				DIRECTIONS[side]
			)

			var neighbor := (
				cell + direction
			)

			# --------------------------------
			# 外墙
			# --------------------------------

			if not occupied_cells.has(
				neighbor
			):
				var external_door := (
					_is_initial_external_door(
						cell,
						side,
						current_room_id
					)
				)

				_create_wall_segment(
					cell,
					side,
					external_door
				)

				continue

			# --------------------------------
			# 与另一个 Cell 相邻
			# --------------------------------

			var neighbor_room_id := int(
				occupied_cells[neighbor]
			)

			# 同一个房间内部：
			# 不生成墙。
			if (
				neighbor_room_id
				== current_room_id
			):
				continue

			# 不同房间共享边：
			#
			# 只允许其中一侧负责生成墙，
			# 防止生成两套重叠墙体。
			if not _should_generate_shared_wall(
				cell,
				neighbor
			):
				continue

			# 不同房间接触：
			# 当前这个 8m 边段一定生成门。
			_create_wall_segment(
				cell,
				side,
				true
			)


func _should_generate_shared_wall(
	cell: Vector2i,
	neighbor: Vector2i
) -> bool:
	if cell.x < neighbor.x:
		return true

	if cell.x > neighbor.x:
		return false

	return cell.y < neighbor.y


func _is_initial_external_door(
	cell: Vector2i,
	side: int,
	room_id: int
) -> bool:
	if room_id != initial_room_id:
		return false

	if cell != initial_room_origin:
		return false

	return side == initial_exit_side


func _create_wall_segment(
	cell: Vector2i,
	side: int,
	has_door: bool
) -> void:
	var center := grid_cell_to_world(
		cell
	)

	center.y = wall_height * 0.5

	match side:
		WallSide.NORTH:
			center.z -= cell_size * 0.5

		WallSide.EAST:
			center.x += cell_size * 0.5

		WallSide.SOUTH:
			center.z += cell_size * 0.5

		WallSide.WEST:
			center.x -= cell_size * 0.5

	if has_door:
		_create_door_wall(
			center,
			side
		)
	else:
		_create_full_wall(
			center,
			side
		)


func _create_full_wall(
	center: Vector3,
	side: int
) -> void:
	var wall_size: Vector3

	if (
		side == WallSide.NORTH
		or side == WallSide.SOUTH
	):
		wall_size = Vector3(
			cell_size,
			wall_height,
			wall_thickness
		)
	else:
		wall_size = Vector3(
			wall_thickness,
			wall_height,
			cell_size
		)

	_create_wall_piece(
		center,
		wall_size
	)


func _create_door_wall(
	center: Vector3,
	side: int
) -> void:
	var side_length := (
		cell_size - door_width
	) * 0.5

	if side_length <= 0.0:
		return

	var offset := (
		door_width * 0.5
		+ side_length * 0.5
	)

	if (
		side == WallSide.NORTH
		or side == WallSide.SOUTH
	):
		var piece_size := Vector3(
			side_length,
			wall_height,
			wall_thickness
		)

		_create_wall_piece(
			center + Vector3(
				-offset,
				0.0,
				0.0
			),
			piece_size
		)

		_create_wall_piece(
			center + Vector3(
				offset,
				0.0,
				0.0
			),
			piece_size
		)

	else:
		var piece_size := Vector3(
			wall_thickness,
			wall_height,
			side_length
		)

		_create_wall_piece(
			center + Vector3(
				0.0,
				0.0,
				-offset
			),
			piece_size
		)

		_create_wall_piece(
			center + Vector3(
				0.0,
				0.0,
				offset
			),
			piece_size
		)


func _create_wall_piece(
	center: Vector3,
	size: Vector3
) -> void:
	var body := StaticBody3D.new()
	body.name = "Wall"

	body.position = center

	_walls_root.add_child(body)

	# -------------------------
	# Visual
	# -------------------------

	var mesh_instance := MeshInstance3D.new()

	var mesh := BoxMesh.new()
	mesh.size = size

	mesh_instance.mesh = mesh
	mesh_instance.material_override = (
		_wall_material
	)

	body.add_child(mesh_instance)

	# -------------------------
	# Collision
	# -------------------------

	var collision := CollisionShape3D.new()

	var shape := BoxShape3D.new()
	shape.size = size

	collision.shape = shape

	body.add_child(collision)


# ============================================================
# Facilities / Future Storage
# ============================================================


func _return_facilities_to_storage(
	room: ShelterRoom
) -> void:
	if room.facilities_root == null:
		return

	for child in room.facilities_root.get_children():
		child.reparent(
			_storage_placeholder,
			false
		)

		if child is Node3D:
			var facility := child as Node3D
			facility.visible = false

		facility_storage_requested.emit(
			child
		)


# ============================================================
# Runtime Roots
# ============================================================


func _create_runtime_roots() -> void:
	_rooms_root = Node3D.new()
	_rooms_root.name = "Rooms"
	add_child(_rooms_root)

	_walls_root = Node3D.new()
	_walls_root.name = "GeneratedWalls"
	add_child(_walls_root)

	_storage_placeholder = Node3D.new()
	_storage_placeholder.name = (
		"FacilityStoragePlaceholder"
	)
	add_child(_storage_placeholder)


func _create_wall_material() -> void:
	_wall_material = StandardMaterial3D.new()

	_wall_material.albedo_color = Color(
		0.32,
		0.33,
		0.36,
		1.0
	)


# ============================================================
# Debug
# ============================================================


func _create_debug_layout() -> void:
	# Initial:
	#
	#         x = 0
	#           ■
	#
	# 向左扩张测试。
	#
	# Large  Medium  Small Initial
	#
	# ■■      ■      ■      ■
	# ■■      ■
	#
	# Large 和 Medium 共享两个 8m 边，
	# 因此这里应该自动出现两扇门。

	add_room(
		RoomType.SMALL,
		Vector2i(-1, 0)
	)

	add_room(
		RoomType.MEDIUM,
		Vector2i(-2, 0),
		true
	)

	add_room(
		RoomType.LARGE,
		Vector2i(-4, 0)
	)
