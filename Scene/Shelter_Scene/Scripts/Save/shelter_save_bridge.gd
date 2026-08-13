extends Node
class_name ShelterSaveBridge


@export_category("References")

@export var room_manager: ShelterRoomManager

@export var facility_build_controller: ShelterFacilityBuildController


var _restoring: bool = false
var _save_queued: bool = false


func _ready() -> void:
	if not _validate_setup():
		return

	_connect_change_signals()

	# 等待 RoomManager 完成自己的 _ready：
	# Initial Room / Runtime Roots 都生成完毕后再读档。
	call_deferred(
		"_restore_from_current_save"
	)


# ============================================================
# Signals
# ============================================================


func _connect_change_signals() -> void:
	if not room_manager.room_added.is_connected(
		_on_shelter_changed
	):
		room_manager.room_added.connect(
			_on_shelter_changed
		)

	if not room_manager.room_moved.is_connected(
		_on_shelter_changed
	):
		room_manager.room_moved.connect(
			_on_shelter_changed
		)

	if not room_manager.room_removed.is_connected(
		_on_shelter_changed
	):
		room_manager.room_removed.connect(
			_on_shelter_changed
		)

	if (
		facility_build_controller != null
		and not facility_build_controller.facility_changed.is_connected(
			_on_facility_changed
		)
	):
		facility_build_controller.facility_changed.connect(
			_on_facility_changed
		)


func _on_shelter_changed(
	_room_id: int
) -> void:
	_queue_save()


func _on_facility_changed() -> void:
	_queue_save()


func _queue_save() -> void:
	if _restoring:
		return

	if _save_queued:
		return

	_save_queued = true

	call_deferred(
		"_save_queued_changes"
	)


func _save_queued_changes() -> void:
	_save_queued = false

	if _restoring:
		return

	save_shelter_now()


# ============================================================
# Save
# ============================================================


func save_shelter_now() -> void:
	if SaveManager.current_save.is_empty():
		push_warning(
			"ShelterSaveBridge: 当前没有加载存档。"
		)
		return

	_sanitize_storage_collisions()

	var shelter_data: Dictionary = {
		"version": 1,
		"rooms": _serialize_rooms(),
		"facility_storage": _serialize_storage()
	}

	SaveManager.set_shelter_data(
		shelter_data,
		true
	)


func _serialize_rooms() -> Array:
	var result: Array = []

	var room_ids: Array = (
		room_manager.rooms.keys()
	)

	room_ids.sort()

	for id_value in room_ids:
		var room_id: int = int(
			id_value
		)

		var room: ShelterRoom = (
			room_manager.get_room(
				room_id
			)
		)

		if room == null:
			continue

		var room_data: Dictionary = {
			"is_initial": (
				room_id
				== room_manager.initial_room_id
			),

			"room_type": room.room_type,

			"origin_cell": [
				room.origin_cell.x,
				room.origin_cell.y
			],

			"rotated": room.rotated,

			"facilities": (
				_serialize_facility_container(
					room.facilities_root
				)
			)
		}

		result.append(
			room_data
		)

	return result


func _serialize_storage() -> Array:
	var storage_root: Node = (
		room_manager.get_node_or_null(
			"FacilityStoragePlaceholder"
		)
	)

	if storage_root == null:
		return []

	return _serialize_facility_container(
		storage_root
	)


func _serialize_facility_container(
	container: Node
) -> Array:
	var result: Array = []

	if container == null:
		return result

	for child in container.get_children():
		if not child is ShelterFacility:
			continue

		var facility: ShelterFacility = (
			child as ShelterFacility
		)

		var scene_path: String = (
			facility.scene_file_path
		)

		if scene_path.is_empty():
			push_warning(
				"ShelterSaveBridge: "
				+ "设施没有 scene_file_path，跳过："
				+ facility.name
			)

			continue

		var state: Dictionary = {}

		if facility.has_method(
			"get_save_state"
		):
			var state_value: Variant = (
				facility.call(
					"get_save_state"
				)
			)

			if typeof(state_value) == TYPE_DICTIONARY:
				state = state_value

		result.append(
			{
				"scene_path": scene_path,

				"facility_id": str(
					facility.facility_id
				),

				"position": [
					facility.position.x,
					facility.position.y,
					facility.position.z
				],

				"rotation_y": (
					facility.rotation.y
				),

				"state": state
			}
		)

	return result


# ============================================================
# Restore
# ============================================================


func _restore_from_current_save() -> void:
	if SaveManager.current_save.is_empty():
		push_warning(
			"ShelterSaveBridge: "
			+ "进入 Shelter 时没有加载存档。"
		)
		return

	_restoring = true

	var shelter_data: Dictionary = (
		SaveManager.get_shelter_data()
	)

	_restore_rooms(
		shelter_data.get(
			"rooms",
			[]
		)
	)

	_restore_storage(
		shelter_data.get(
			"facility_storage",
			[]
		)
	)

	_restoring = false

	# 旧存档第一次进入 Shelter 时，
	# 会在这里升级成完整的 Shelter 数据结构。
	save_shelter_now()


func _restore_rooms(
	room_list_value: Variant
) -> void:
	if typeof(room_list_value) != TYPE_ARRAY:
		return

	var room_list: Array = room_list_value

	# --------------------------------------------------------
	# Initial Room
	#
	# Initial Room 本身由场景系统生成，
	# 不重新创建。
	#
	# 这里只恢复 Initial Room 内的玩家设施。
	# --------------------------------------------------------

	for entry_value in room_list:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = entry_value

		if not bool(
			entry.get(
				"is_initial",
				false
			)
		):
			continue

		var initial_room: ShelterRoom = (
			room_manager.get_room(
				room_manager.initial_room_id
			)
		)

		if initial_room != null:
			_restore_facilities(
				entry.get(
					"facilities",
					[]
				),
				initial_room.facilities_root,
				initial_room.room_id,
				true
			)

	# --------------------------------------------------------
	# Player-created Rooms
	#
	# 不使用旧 room_id 恢复。
	#
	# 因为玩家删除房间后 ID 可能存在空洞。
	#
	# 使用迭代方式：
	# 每一轮恢复当前能够连接到基地的房间，
	# 直到完整连通布局被恢复。
	# --------------------------------------------------------

	var pending: Array = []

	for entry_value in room_list:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = entry_value

		if bool(
			entry.get(
				"is_initial",
				false
			)
		):
			continue

		pending.append(
			entry.duplicate(
				true
			)
		)

	var safety: int = 0

	while (
		not pending.is_empty()
		and safety < 10000
	):
		safety += 1

		var placed_any: bool = false

		for index in range(
			pending.size() - 1,
			-1,
			-1
		):
			var entry: Dictionary = pending[
				index
			]

			var origin: Vector2i = (
				_read_origin_cell(
					entry
				)
			)

			var room_type: int = int(
				entry.get(
					"room_type",
					0
				)
			)

			var rotated: bool = bool(
				entry.get(
					"rotated",
					false
				)
			)

			var footprint: Vector2i = (
				room_manager.get_room_footprint(
					room_type,
					rotated
				)
			)

			if not room_manager.can_place_room(
				origin,
				footprint
			):
				continue

			var new_room_id: int = (
				room_manager.add_room(
					room_type,
					origin,
					rotated
				)
			)

			if new_room_id < 0:
				continue

			var room: ShelterRoom = (
				room_manager.get_room(
					new_room_id
				)
			)

			if room != null:
				_restore_facilities(
					entry.get(
						"facilities",
						[]
					),
					room.facilities_root,
					new_room_id,
					true
				)

			pending.remove_at(
				index
			)

			placed_any = true

		if not placed_any:
			push_error(
				"ShelterSaveBridge: "
				+ "存在无法恢复的断开房间布局。"
			)

			break


func _restore_storage(
	storage_value: Variant
) -> void:
	if typeof(storage_value) != TYPE_ARRAY:
		return

	var storage_root: Node = (
		room_manager.get_node_or_null(
			"FacilityStoragePlaceholder"
		)
	)

	if storage_root == null:
		push_warning(
			"ShelterSaveBridge: "
			+ "找不到 FacilityStoragePlaceholder。"
		)
		return

	_restore_facilities(
		storage_value,
		storage_root,
		-1,
		false
	)

	_sanitize_storage_collisions()


func _restore_facilities(
	facility_value: Variant,
	parent: Node,
	room_id: int,
	visible: bool
) -> void:
	if typeof(facility_value) != TYPE_ARRAY:
		return

	var facility_list: Array = facility_value

	for data_value in facility_list:
		if typeof(data_value) != TYPE_DICTIONARY:
			continue

		var data: Dictionary = data_value

		var scene_path: String = str(
			data.get(
				"scene_path",
				""
			)
		)

		if scene_path.is_empty():
			continue

		if not ResourceLoader.exists(
			scene_path
		):
			push_warning(
				"ShelterSaveBridge: "
				+ "设施场景不存在："
				+ scene_path
			)

			continue

		var resource: Resource = load(
			scene_path
		)

		if not resource is PackedScene:
			continue

		var packed_scene: PackedScene = (
			resource as PackedScene
		)

		var instance: Node = (
			packed_scene.instantiate()
		)

		if not instance is ShelterFacility:
			instance.queue_free()
			continue

		var facility: ShelterFacility = (
			instance as ShelterFacility
		)

		parent.add_child(
			facility
		)

		var position_array: Array = (
			data.get(
				"position",
				[
					0.0,
					0.0,
					0.0
				]
			)
		)

		facility.position = Vector3(
			_get_array_float(
				position_array,
				0
			),
			_get_array_float(
				position_array,
				1
			),
			_get_array_float(
				position_array,
				2
			)
		)

		facility.rotation = Vector3(
			0.0,
			float(
				data.get(
					"rotation_y",
					0.0
				)
			),
			0.0
		)

		facility.set_room_id(
			room_id
		)

		facility.visible = visible

		var state_value: Variant = data.get(
			"state",
			{}
		)

		if (
			typeof(state_value) == TYPE_DICTIONARY
			and facility.has_method(
				"apply_save_state"
			)
		):
			facility.call(
				"apply_save_state",
				state_value
			)


# ============================================================
# Storage Collision Safety
# ============================================================


func _sanitize_storage_collisions() -> void:
	var storage_root: Node = (
		room_manager.get_node_or_null(
			"FacilityStoragePlaceholder"
		)
	)

	if storage_root == null:
		return

	for child in storage_root.get_children():
		if child is Node3D:
			(child as Node3D).visible = false

		_set_collision_enabled_recursive(
			child,
			false
		)


func _set_collision_enabled_recursive(
	node: Node,
	enabled: bool
) -> void:
	if node is CollisionShape3D:
		var shape: CollisionShape3D = (
			node as CollisionShape3D
		)

		shape.set_deferred(
			"disabled",
			not enabled
		)

	for child in node.get_children():
		_set_collision_enabled_recursive(
			child,
			enabled
		)


# ============================================================
# Utility
# ============================================================


func _read_origin_cell(
	data: Dictionary
) -> Vector2i:
	var array_value: Variant = data.get(
		"origin_cell",
		[
			0,
			0
		]
	)

	if typeof(array_value) != TYPE_ARRAY:
		return Vector2i.ZERO

	var values: Array = array_value

	return Vector2i(
		int(
			_get_array_float(
				values,
				0
			)
		),
		int(
			_get_array_float(
				values,
				1
			)
		)
	)


func _get_array_float(
	array: Array,
	index: int
) -> float:
	if index < 0:
		return 0.0

	if index >= array.size():
		return 0.0

	return float(
		array[index]
	)


func _validate_setup() -> bool:
	var valid: bool = true

	if room_manager == null:
		push_error(
			"ShelterSaveBridge: RoomManager 未绑定。"
		)

		valid = false

	if facility_build_controller == null:
		push_error(
			"ShelterSaveBridge: FacilityBuildController 未绑定。"
		)

		valid = false

	return valid
