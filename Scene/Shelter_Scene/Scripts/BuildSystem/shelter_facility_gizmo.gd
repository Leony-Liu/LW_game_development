extends Node3D
class_name ShelterFacilityGizmo


# ============================================================
# Shelter Facility Gizmo
# ============================================================
#
# Translation Mode
#
#      Z
#      ↑
#      │
#      ■────→ X
#
# ■ = XZ Plane Handle
#
#
# Rotation Mode
#
# 按住 Shift：
#
# Translation Gizmo 隐藏
# Green Y Rotation Ring 显示
#
#
# Gizmo 本身没有 Physics Collision。
# 鼠标命中完全由平面坐标计算完成。
# ============================================================


enum Handle {
	NONE,
	X_AXIS,
	Z_AXIS,
	XZ_PLANE,
	Y_ROTATION
}


@export_category("Translation")

## 中央 XZ 平面拖拽块边长。
@export var center_size: float = 0.5

## 箭头杆长度。
@export var axis_length: float = 1.0

## 箭头杆粗细。
@export var axis_thickness: float = 0.065

## 箭头锥体长度。
@export var arrow_head_length: float = 0.28

## 箭头锥体半径。
@export var arrow_head_radius: float = 0.13

## 鼠标命中轴时允许的宽度。
##
## 稍微比视觉模型宽一点，
## 操作会更容易。
@export var axis_pick_half_width: float = 0.14


@export_category("Rotation")

## Y 轴旋转环内半径。
@export var rotation_inner_radius: float = 1.05

## Y 轴旋转环外半径。
@export var rotation_outer_radius: float = 1.22

## 鼠标命中旋转环的额外容错。
@export var rotation_pick_margin: float = 0.12


@export_category("Position")

## Gizmo 放在设施顶部再向上多少。
@export var vertical_offset: float = 0.12


var rotation_mode_enabled: bool = false


var _translation_root: Node3D
var _rotation_root: Node3D

var _x_material: StandardMaterial3D
var _z_material: StandardMaterial3D
var _center_material: StandardMaterial3D
var _rotation_material: StandardMaterial3D


func _ready() -> void:
	_create_materials()
	_create_visuals()

	set_rotation_mode(false)


# ============================================================
# Public API
# ============================================================


func sync_to_facility(
	facility: ShelterFacility
) -> void:
	if facility == null:
		visible = false
		return

	visible = true

	# Gizmo 使用世界 X / Z 轴。
	#
	# 即使设施本身发生旋转，
	# 平移轴也不会跟着设施旋转。
	global_rotation = Vector3.ZERO

	global_position = (
		facility.global_position
		+ Vector3.UP
		* (
			facility.placement_size.y
			+ vertical_offset
		)
	)


func set_rotation_mode(
	enabled: bool
) -> void:
	rotation_mode_enabled = enabled

	if _translation_root != null:
		_translation_root.visible = not enabled

	if _rotation_root != null:
		_rotation_root.visible = enabled


func pick_handle(
	world_point: Vector3
) -> int:
	var local_point := to_local(
		world_point
	)

	if rotation_mode_enabled:
		return _pick_rotation_handle(
			local_point
		)

	return _pick_translation_handle(
		local_point
	)


func get_gizmo_plane_height() -> float:
	return global_position.y


# ============================================================
# Picking
# ============================================================


func _pick_translation_handle(
	local_point: Vector3
) -> int:
	var half_center := center_size * 0.5

	# --------------------------------------------------------
	# Center XZ Plane
	# --------------------------------------------------------

	if (
		absf(local_point.x) <= half_center
		and absf(local_point.z) <= half_center
	):
		return Handle.XZ_PLANE

	# --------------------------------------------------------
	# X Axis
	# --------------------------------------------------------

	var axis_start := half_center

	var axis_end := (
		half_center
		+ axis_length
		+ arrow_head_length
	)

	if (
		local_point.x >= axis_start
		and local_point.x <= axis_end
		and absf(local_point.z)
		<= axis_pick_half_width
	):
		return Handle.X_AXIS

	# --------------------------------------------------------
	# Z Axis
	# --------------------------------------------------------

	if (
		local_point.z >= axis_start
		and local_point.z <= axis_end
		and absf(local_point.x)
		<= axis_pick_half_width
	):
		return Handle.Z_AXIS

	return Handle.NONE


func _pick_rotation_handle(
	local_point: Vector3
) -> int:
	var radius := Vector2(
		local_point.x,
		local_point.z
	).length()

	var min_radius := (
		rotation_inner_radius
		- rotation_pick_margin
	)

	var max_radius := (
		rotation_outer_radius
		+ rotation_pick_margin
	)

	if (
		radius >= min_radius
		and radius <= max_radius
	):
		return Handle.Y_ROTATION

	return Handle.NONE


# ============================================================
# Visual Creation
# ============================================================


func _create_visuals() -> void:
	_translation_root = Node3D.new()
	_translation_root.name = "Translation"

	add_child(
		_translation_root
	)

	_rotation_root = Node3D.new()
	_rotation_root.name = "Rotation"

	add_child(
		_rotation_root
	)

	_create_center_handle()

	_create_x_axis()
	_create_z_axis()

	_create_rotation_ring()


func _create_center_handle() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "XZPlaneHandle"

	var mesh := BoxMesh.new()

	mesh.size = Vector3(
		center_size,
		0.035,
		center_size
	)

	mesh_instance.mesh = mesh

	mesh_instance.material_override = (
		_center_material
	)

	_translation_root.add_child(
		mesh_instance
	)


# ============================================================
# X Axis
# ============================================================


func _create_x_axis() -> void:
	var half_center := center_size * 0.5

	# --------------------------------------------------------
	# Shaft
	# --------------------------------------------------------

	var shaft := MeshInstance3D.new()
	shaft.name = "XAxisShaft"

	var shaft_mesh := BoxMesh.new()

	shaft_mesh.size = Vector3(
		axis_length,
		axis_thickness,
		axis_thickness
	)

	shaft.mesh = shaft_mesh

	shaft.position.x = (
		half_center
		+ axis_length * 0.5
	)

	shaft.material_override = (
		_x_material
	)

	_translation_root.add_child(
		shaft
	)

	# --------------------------------------------------------
	# Arrow Head
	# --------------------------------------------------------

	var head := MeshInstance3D.new()
	head.name = "XAxisArrow"

	var head_mesh := CylinderMesh.new()

	# CylinderMesh 默认沿 Y 轴。
	# top_radius = 0 形成圆锥。
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = (
		arrow_head_radius
	)
	head_mesh.height = (
		arrow_head_length
	)
	head_mesh.radial_segments = 16

	head.mesh = head_mesh

	head.position.x = (
		half_center
		+ axis_length
		+ arrow_head_length * 0.5
	)

	# +Y → +X
	head.rotation.z = (
		-deg_to_rad(90.0)
	)

	head.material_override = (
		_x_material
	)

	_translation_root.add_child(
		head
	)


# ============================================================
# Z Axis
# ============================================================


func _create_z_axis() -> void:
	var half_center := center_size * 0.5

	# --------------------------------------------------------
	# Shaft
	# --------------------------------------------------------

	var shaft := MeshInstance3D.new()
	shaft.name = "ZAxisShaft"

	var shaft_mesh := BoxMesh.new()

	shaft_mesh.size = Vector3(
		axis_thickness,
		axis_thickness,
		axis_length
	)

	shaft.mesh = shaft_mesh

	shaft.position.z = (
		half_center
		+ axis_length * 0.5
	)

	shaft.material_override = (
		_z_material
	)

	_translation_root.add_child(
		shaft
	)

	# --------------------------------------------------------
	# Arrow Head
	# --------------------------------------------------------

	var head := MeshInstance3D.new()
	head.name = "ZAxisArrow"

	var head_mesh := CylinderMesh.new()

	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = (
		arrow_head_radius
	)
	head_mesh.height = (
		arrow_head_length
	)
	head_mesh.radial_segments = 16

	head.mesh = head_mesh

	head.position.z = (
		half_center
		+ axis_length
		+ arrow_head_length * 0.5
	)

	# +Y → +Z
	head.rotation.x = (
		deg_to_rad(90.0)
	)

	head.material_override = (
		_z_material
	)

	_translation_root.add_child(
		head
	)


# ============================================================
# Rotation Ring
# ============================================================


func _create_rotation_ring() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "YRotationRing"

	var ring_mesh := TorusMesh.new()

	ring_mesh.inner_radius = (
		rotation_inner_radius
	)

	ring_mesh.outer_radius = (
		rotation_outer_radius
	)

	ring_mesh.rings = 48
	ring_mesh.ring_segments = 12

	ring.mesh = ring_mesh

	ring.material_override = (
		_rotation_material
	)

	_rotation_root.add_child(
		ring
	)


# ============================================================
# Materials
# ============================================================


func _create_materials() -> void:
	_x_material = _create_material(
		Color(
			1.0,
			0.15,
			0.15,
			1.0
		),
		false
	)

	_z_material = _create_material(
		Color(
			0.15,
			0.45,
			1.0,
			1.0
		),
		false
	)

	_center_material = _create_material(
		Color(
			0.95,
			0.85,
			0.2,
			0.72
		),
		true
	)

	_rotation_material = _create_material(
		Color(
			0.15,
			1.0,
			0.3,
			0.92
		),
		true
	)


func _create_material(
	color: Color,
	transparent: bool
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()

	material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)

	material.albedo_color = color

	if transparent:
		material.transparency = (
			BaseMaterial3D.TRANSPARENCY_ALPHA
		)

	return material
