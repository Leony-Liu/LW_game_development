## 根据 World 地图数据创建并清理房间实例。
## 保留原 RoomData 到真实房间及敌人接近目标的查找关系。
class_name RoomSet
extends Node3D

@export_group("场景预制体")
@export var battle_room_scene: PackedScene

var _room_instances_by_data: Dictionary = {}


## 接收地图数据；任一必需房间失败时清除本批实例并返回失败。
func build_rooms(mapdata: Dictionary) -> bool:
	clear_rooms()
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
		add_child(room_instance)
		if not room_instance.is_assembled:
			return _fail_build("房间 %s 的必需结构未完成。" % pos)
		# 坐标映射至 3D 空间
		room_instance.position = Vector3(pos.x, 0.0, pos.y)
		room_instance.name = "Room_%d_%d" % [int(pos.x), int(pos.y)]
		_room_instances_by_data[room_data] = room_instance
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


# 返回指定房间当前敌人的世界空间接近目标。
func get_encounter_approach_target(room_data: RoomData) -> Node3D:
	var room_instance := get_room_instance(room_data)
	if room_instance == null:
		return null
	return room_instance.get_encounter_approach_target()

# 清空所有房间
func clear_rooms() -> void:
	_room_instances_by_data.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
