class_name WorldGenerator
extends Node

const ROOM_SIZE: float = 10.0
const HALF_ROOM_SIZE: float = ROOM_SIZE * 0.5


## 动态调节系数
# 敌人生成概率
var enemy_spawn_chance: float = 0.7
# 地牢形状生成偏好
var corridor_bias: float = 0.0

# 坐标映射 (2D 空间对应 3D 水平面 X / Z)
const DIRECTIONS: Dictionary = {
	RoomData.Direction.EAST: Vector2(ROOM_SIZE, 0),
	RoomData.Direction.WEST: Vector2(-ROOM_SIZE, 0),
	RoomData.Direction.SOUTH: Vector2(0, ROOM_SIZE),
	RoomData.Direction.NORTH: Vector2(0, -ROOM_SIZE)
}


## 生成地图蓝本数据 mapdata
func generate(room_count: int) -> Dictionary:
	var rooms: Dictionary = {}
	var doors: Dictionary = {}
	
	if room_count <= 0:
		return { "rooms": rooms, "doors": doors }

	# 1. 创建位于 (0, 0) 的初始房间
	var start_pos = Vector2.ZERO
	var start_room = RoomData.new()
	start_room.room_position = start_pos
	start_room.room_type = RoomData.RoomType.INITIAL
	start_room.has_enemies = false
	start_room.is_player_inside = true
	rooms[start_pos] = start_room

	# 2. 随机向四周扩展生成普通房间
	var room_positions: Array[Vector2] = [start_pos]
	var dir_keys = DIRECTIONS.keys()

	while rooms.size() < room_count:
		var current_pos: Vector2
		if corridor_bias > 0.0 and randf() < corridor_bias:
			current_pos = room_positions.back()
		else:
			current_pos = room_positions.pick_random()

		var random_dir: RoomData.Direction = dir_keys.pick_random()
		var offset: Vector2 = DIRECTIONS[random_dir]
		var next_pos: Vector2 = current_pos + offset

		if not rooms.has(next_pos):
			var new_room = RoomData.new()
			new_room.room_position = next_pos
			new_room.room_type = RoomData.RoomType.NORMAL
			new_room.has_enemies = randf() < enemy_spawn_chance
			new_room.entry_direction = random_dir
			
			rooms[next_pos] = new_room
			room_positions.append(next_pos)

	# 3. 计算所有相邻连通关系：双向登记 connected_doors，并记录门坐标与走向
	for pos in rooms.keys():
		var current_room: RoomData = rooms[pos]

		# 检查东边 (+X)
		var east_pos = pos + DIRECTIONS[RoomData.Direction.EAST]
		if rooms.has(east_pos):
			var door_pos = pos + Vector2(HALF_ROOM_SIZE, 0)
			doors[door_pos] = "horizontal" # 东西向门
			
			_connect_rooms(current_room, rooms[east_pos], RoomData.Direction.EAST, RoomData.Direction.WEST)

		# 检查南边 (+Z)
		var south_pos = pos + DIRECTIONS[RoomData.Direction.SOUTH]
		if rooms.has(south_pos):
			var door_pos = pos + Vector2(0, HALF_ROOM_SIZE)
			doors[door_pos] = "vertical" # 南北向门
			
			_connect_rooms(current_room, rooms[south_pos], RoomData.Direction.SOUTH, RoomData.Direction.NORTH)

	# 返回最终生成的 mapdata
	return {
		"rooms": rooms,
		"doors": doors
	}


## 双向登记相邻房间的连通方向
func _connect_rooms(room_a: RoomData, room_b: RoomData, dir_a_to_b: RoomData.Direction, dir_b_to_a: RoomData.Direction) -> void:
	if not dir_a_to_b in room_a.connected_doors:
		room_a.connected_doors.append(dir_a_to_b)
		
	if not dir_b_to_a in room_b.connected_doors:
		room_b.connected_doors.append(dir_b_to_a)
