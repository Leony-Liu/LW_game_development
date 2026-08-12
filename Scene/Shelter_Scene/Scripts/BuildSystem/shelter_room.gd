extends Node3D
class_name ShelterRoom


# ============================================================
# Shelter Room
# ============================================================
#
# 一个基地房间的逻辑节点。
#
# 房间本身只负责：
# - 房间尺寸
# - 网格位置
# - 地板
# - 房间内部设施
#
# 墙壁和门统一由 ShelterRoomManager 生成，
# 防止两个相邻房间各自生成一堵墙造成重叠。
# ============================================================


var room_id: int = -1

## 0 = Small
## 1 = Medium
## 2 = Large
var room_type: int = 0

## 房间占据区域左上/起始格。
var origin_cell: Vector2i = Vector2i.ZERO

## 房间占据多少基础格。
##
## Small  = 1 x 1
## Medium = 2 x 1 / 1 x 2
## Large  = 2 x 2
var footprint: Vector2i = Vector2i.ONE

## Medium 是否旋转为 1 x 2。
var rotated: bool = false

## 初始房间锁定，不允许移动和删除。
var locked: bool = false

## 一个基础格的尺寸。
var cell_size: float = 8.0


var facilities_root: Node3D

var _floor_body: StaticBody3D

const FLOOR_THICKNESS: float = 0.2


func configure(
	new_room_id: int,
	new_room_type: int,
	new_origin_cell: Vector2i,
	new_footprint: Vector2i,
	new_rotated: bool,
	new_locked: bool,
	new_cell_size: float
) -> void:
	room_id = new_room_id
	room_type = new_room_type
	origin_cell = new_origin_cell
	footprint = new_footprint
	rotated = new_rotated
	locked = new_locked
	cell_size = new_cell_size

	name = "Room_%03d" % room_id

	_ensure_facilities_root()
	_update_world_position()
	_rebuild_floor()


func set_layout(
	new_origin_cell: Vector2i,
	new_footprint: Vector2i,
	new_rotated: bool,
	rotate_contents: bool = false
) -> void:
	if (
		rotate_contents
		and rotated != new_rotated
	):
		var rotation_delta: float

		if new_rotated:
			rotation_delta = PI * 0.5
		else:
			rotation_delta = -PI * 0.5

		_rotate_facilities(rotation_delta)

	origin_cell = new_origin_cell
	footprint = new_footprint
	rotated = new_rotated

	_update_world_position()
	_rebuild_floor()


func get_occupied_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for x in range(footprint.x):
		for z in range(footprint.y):
			result.append(
				origin_cell + Vector2i(x, z)
			)

	return result


func _ensure_facilities_root() -> void:
	if facilities_root != null:
		return

	facilities_root = Node3D.new()
	facilities_root.name = "Facilities"

	add_child(facilities_root)


func _update_world_position() -> void:
	# Grid 中：
	#
	# Cell (0, 0) 中心位于世界坐标 (0, 0, 0)
	#
	# 2x1 房间：
	# 两格中心分别位于 0 和 8，
	# 所以整个房间中心位于 4。
	var center_x: float = (
		float(origin_cell.x)
		+ float(footprint.x - 1) * 0.5
	) * cell_size

	var center_z: float = (
		float(origin_cell.y)
		+ float(footprint.y - 1) * 0.5
	) * cell_size

	position = Vector3(
		center_x,
		0.0,
		center_z
	)


func _rebuild_floor() -> void:
	if is_instance_valid(_floor_body):
		_floor_body.free()

	_floor_body = StaticBody3D.new()
	_floor_body.name = "Floor"

	add_child(_floor_body)

	var floor_size := Vector3(
		float(footprint.x) * cell_size,
		FLOOR_THICKNESS,
		float(footprint.y) * cell_size
	)

	# -------------------------
	# Visual
	# -------------------------

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"

	var box_mesh := BoxMesh.new()
	box_mesh.size = floor_size

	mesh_instance.mesh = box_mesh
	mesh_instance.position.y = -FLOOR_THICKNESS * 0.5

	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(
		0.42,
		0.44,
		0.48,
		1.0
	)

	mesh_instance.material_override = floor_material

	_floor_body.add_child(mesh_instance)

	# -------------------------
	# Collision
	# -------------------------

	var collision := CollisionShape3D.new()
	collision.name = "Collision"

	var box_shape := BoxShape3D.new()
	box_shape.size = floor_size

	collision.shape = box_shape
	collision.position.y = -FLOOR_THICKNESS * 0.5

	_floor_body.add_child(collision)


func _rotate_facilities(angle: float) -> void:
	if facilities_root == null:
		return

	var rotation_basis := Basis(
		Vector3.UP,
		angle
	)

	for child in facilities_root.get_children():
		if not child is Node3D:
			continue

		var facility := child as Node3D

		# 绕房间中心旋转设施的位置。
		facility.position = (
			rotation_basis
			* facility.position
		)

		# 同时旋转设施自己的朝向。
		facility.rotate_y(angle)
