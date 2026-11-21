## 根据 World 地图数据创建并清理房间实例。
## 保留原 RoomData 到真实房间及敌人接近目标的查找关系。
class_name RoomSet
extends Node3D

signal extraction_requested(room: RoomData, facility: Node3D)
signal workbench_requested(room: RoomData, facility: Node3D)
signal player_entered_room(room_coords: Vector2)
@export_group("场景预制体")
@export var battle_room_scene: PackedScene

var _room_instances_by_data: Dictionary = {}
var _entry_player: CharacterBody3D
var _workbench_generation_complete := false

# World 提供真实玩家引用，房间只接受这一个物理体。
func configure_entry_player(player_body: CharacterBody3D) -> bool:
	if not is_instance_valid(player_body):
		push_error("[RoomSet] 入室检测配置失败：缺少真实玩家物理体。")
		return false
	_entry_player = player_body
	return true

# 初次物理同步后通过房间原有触发器补查重叠，不按生成坐标推定占用。
func refresh_player_room_occupancy() -> void:
	for room in _room_instances_by_data.values():
		room.refresh_player_room_occupancy()

# 只中继当前装配实例和原 RoomData，旧房间通知不能污染新地图。
func _on_player_entered(room_data: RoomData, room: BattleRoom) -> void:
	if get_room_instance(room_data) == room and room.is_player_inside_entry():
		player_entered_room.emit(room_data.room_position)


## 接收地图数据；任一必需房间失败时清除本批实例并返回失败。
func build_rooms(mapdata: Dictionary) -> bool:
	clear_rooms()
	if not is_instance_valid(_entry_player):
		push_error("[RoomSet] 房间组装失败：入室检测尚未绑定真实玩家物理体。")
		return false
	var rooms_value: Variant = mapdata.get("rooms")
	if not rooms_value is Dictionary or rooms_value.is_empty():
		push_error("RoomSet ： 房间组装失败：地图缺少有效房间数据。")
		return false
	if battle_room_scene == null:
		push_error("RoomSet ： 房间组装失败：缺少 battle_room_scene。")
		return false
	var rooms: Dictionary = rooms_value
	print("RoomSet ： 开始组装房间，数量：%d。" % rooms.size())
	for pos in rooms.keys():
		var room_data: Variant = rooms[pos]
		if not pos is Vector2 or not room_data is RoomData or room_data.room_position != pos:
			return _fail_build("房间坐标或 RoomData 无效。")
		var room_instance := battle_room_scene.instantiate()
		if not room_instance is BattleRoom:
			if room_instance != null:
				room_instance.free()
			return _fail_build("battle_room_scene 根节点不是 BattleRoom。")
		room_instance.room_data = room_data
		room_instance.configure_entry_player(_entry_player)
		add_child(room_instance)
		if not room_instance.is_assembled:
			return _fail_build("房间 %s 的必需结构未完成。" % pos)
		# 坐标映射至 3D 空间
		room_instance.position = Vector3(pos.x, 0.0, pos.y)
		room_instance.name = "Room_%d_%d" % [int(pos.x), int(pos.y)]
		_room_instances_by_data[room_data] = room_instance
		room_instance.extraction_requested.connect(_on_extraction_requested)
		room_instance.workbench_requested.connect(_on_workbench_requested)
		room_instance.player_entered.connect(_on_player_entered.bind(room_instance))
	print("RoomSet ： 房间组装完成，数量：%d。" % _room_instances_by_data.size())
	return true


# 报告失败并撤下本批全部房间，避免留下半张地图。
func _fail_build(reason: String) -> bool:
	push_error("RoomSet ： 房间组装失败：%s" % reason)
	clear_rooms()
	return false


# 按原 RoomData 身份查找对应的真实房间实例。
func get_room_instance(room_data: RoomData) -> BattleRoom:
	if room_data == null:
		return null
	var room_instance: BattleRoom = _room_instances_by_data.get(room_data)
	if not is_instance_valid(room_instance):
		return null
	return room_instance


# 只中继仍由当前 RoomSet 索引持有的设施，拒绝旧地图回调。
func _on_extraction_requested(room_data: RoomData, facility: Node3D) -> void:
	if facility != null and get_extraction_facility(room_data) == facility:
		extraction_requested.emit(room_data, facility)


# 使用现有 RoomData 索引查询初始房设施，不建立第二套注册表。
func get_extraction_facility(room_data: RoomData) -> Node3D:
	var room := get_room_instance(room_data)
	return room.get_extraction_facility() if room != null else null

# 沿原房间索引查找设施身份，供共享交互仲裁使用。
func get_workbench_facility(room_data: RoomData) -> Node3D:
	var room := get_room_instance(room_data)
	return room.get_workbench_facility() if room != null else null

# 只中继当前装配设施，不接受旧地图的回调。
func _on_workbench_requested(room_data: RoomData, facility: Node3D) -> void:
	if is_instance_valid(facility) and get_workbench_facility(room_data) == facility:
		workbench_requested.emit(room_data, facility)

# 返回现有设施与原 RoomData，数组仅作查询结果。
func get_workbench_rooms() -> Array[RoomData]:
	var rooms: Array[RoomData] = []
	for data in _room_instances_by_data:
		if get_workbench_facility(data) != null:
			rooms.append(data)
	return rooms


# 返回指定房间当前敌人的世界空间接近目标。
func get_encounter_approach_target(room_data: RoomData) -> Node3D:
	var room_instance := get_room_instance(room_data)
	if room_instance == null:
		return null
	return room_instance.get_encounter_approach_target()

# 仅接受当前索引内的真实装配房间和权威生成数据。
func get_eligible_workbench_rooms() -> Array[RoomData]:
	var eligible: Array[RoomData] = []
	for data in _room_instances_by_data:
		if not data is RoomData or not data.room_position.is_finite():
			continue
		var room := get_room_instance(data)
		if room == null or not room.is_inside_tree() or room.is_queued_for_deletion() or room.get_parent() != self or room.room_data != data:
			continue
		if not room.global_position.is_finite() or not room.global_basis.is_finite() or is_zero_approx(room.global_basis.determinant()):
			continue
		if room.can_host_workbench() and room.get_workbench_facility() == null:
			eligible.append(data)
	return eligible

# 一次批次均匀抽取且不放回；当前 World 只请求一个。
func generate_workbench_facilities(target_count: int = 1, rng: RandomNumberGenerator = null) -> int:
	if target_count < 1 or not is_instance_valid(_entry_player):
		push_error("[RoomSet] 工作台生成失败：数量必须为正且需要真实玩家。")
		return 0
	if _workbench_generation_complete:
		return get_workbench_facility_count()
	var eligible := get_eligible_workbench_rooms()
	if eligible.is_empty():
		push_error("[RoomSet] 工作台生成失败：没有非初始、非敌人的有效房间。")
		return 0
	var count := mini(target_count, eligible.size())
	if count < target_count:
		push_warning("[RoomSet] 工作台目标数量超过可用房间；本次仅放置 %d 个。" % count)
	var placed: Array[BattleRoom] = []
	for i in count:
		var index := rng.randi_range(0, eligible.size() - 1) if rng != null else randi_range(0, eligible.size() - 1)
		var room := get_room_instance(eligible[index])
		eligible.remove_at(index)
		if not room.place_workbench_facility(_entry_player):
			for previous in placed:
				previous.clear_workbench_facility()
			push_error("[RoomSet] 工作台生成失败：放置失败，已撤回本批设施。")
			return 0
		placed.append(room)
	_workbench_generation_complete = true
	print("[RoomSet] 工作台设施生成完成，数量：%d。" % placed.size())
	return placed.size()

# 从原房间索引查询实际数量，不建立第二套设施注册表。
func get_workbench_facility_count() -> int:
	var count := 0
	for data in _room_instances_by_data:
		var room := get_room_instance(data)
		if room != null and room.get_workbench_facility() != null:
			count += 1
	return count

# 清空所有房间
func clear_rooms() -> void:
	_workbench_generation_complete = false
	_room_instances_by_data.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
