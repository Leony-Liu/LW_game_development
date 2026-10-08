## 根据 World 地图数据创建并清理房间实例。
## 保留原 RoomData 到真实房间及敌人接近目标的查找关系。
class_name RoomSet
extends Node3D

const HALF_ROOM_SIZE: float = 5.0

@export_group("场景预制体")
@export var battle_room_scene: PackedScene

var _room_instances_by_data: Dictionary = {}


## 接收完整地图蓝图构建所有房间
func build_rooms(mapdata: Dictionary) -> void:
	clear_rooms()

	if not battle_room_scene:
		push_error("RoomSet: 未绑定 battle_room_scene！")
		return

	var rooms: Dictionary = mapdata.get("rooms", {})
	var doors: Dictionary = mapdata.get("doors", {})

	for pos: Vector2 in rooms.keys():
		var room_data: RoomData = rooms[pos]
		var room_instance = battle_room_scene.instantiate()

		# 1. 注入纯数值数据
		if "room_data" in room_instance:
			room_instance.room_data = room_data

		# 2. 从门字典中计算该房间朝向哪些方向有门洞
		var open_doors: Array[RoomData.Direction] = []
		if doors.has(pos + Vector2(0, -HALF_ROOM_SIZE)):
			open_doors.append(RoomData.Direction.NORTH)
		if doors.has(pos + Vector2(0, HALF_ROOM_SIZE)):
			open_doors.append(RoomData.Direction.SOUTH)
		if doors.has(pos + Vector2(HALF_ROOM_SIZE, 0)):
			open_doors.append(RoomData.Direction.EAST)
		if doors.has(pos + Vector2(-HALF_ROOM_SIZE, 0)):
			open_doors.append(RoomData.Direction.WEST)

		# 3. 将门洞布局直接告知 BattleRoom（不污染 RoomData）
		if "connected_doors" in room_instance:
			room_instance.connected_doors = open_doors

		add_child(room_instance)

		# 4. 坐标映射至 3D 空间
		room_instance.position = Vector3(pos.x, 0.0, pos.y)
		room_instance.name = "Room_%d_%d" % [int(pos.x), int(pos.y)]
		_room_instances_by_data[room_data] = room_instance


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
		child.queue_free()
