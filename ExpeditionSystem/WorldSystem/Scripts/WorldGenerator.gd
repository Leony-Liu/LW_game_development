class_name WorldGenerator
extends Node

# 房间规模参数
const ROOM_SIZE: float = 10.0
const HALF_ROOM_SIZE: float = ROOM_SIZE * 0.5

# 地牢形状生成偏好 (硬编码：0.0 为网状/树状聚落，数值越高越偏向单向长廊深处延展)
const CORRIDOR_BIAS: float = 0.1

# 坐标映射 (2D 空间对应 3D 水平面 X / Z)
const DIRECTIONS: Dictionary = {
	RoomData.Direction.EAST: Vector2(ROOM_SIZE, 0),
	RoomData.Direction.WEST: Vector2(-ROOM_SIZE, 0),
	RoomData.Direction.SOUTH: Vector2(0, ROOM_SIZE),
	RoomData.Direction.NORTH: Vector2(0, -ROOM_SIZE)
}


## 生成地图蓝本数据 mapdata
func generate(blueprint: MapBlueprint) -> Dictionary:
	var rooms: Dictionary = {}
	var doors: Dictionary = {}
	
	if not blueprint:
		push_error("WorldGenerator: 传入的 MapBlueprint 为空！")
		return { "rooms": rooms, "doors": doors }

	# 根据基准数量和波动比率计算最终目标房间数
	var min_count := int(round(blueprint.base_room_count * (1.0 - blueprint.count_variance)))
	var max_count := int(round(blueprint.base_room_count * (1.0 + blueprint.count_variance)))
	var target_room_count := clampi(randi_range(min_count, max_count), 1, 999)

	# 1. 创建位于 (0, 0) 的初始房间
	var start_pos = Vector2.ZERO
	var start_room = RoomData.new()
	start_room.room_position = start_pos
	start_room.room_type = RoomData.RoomType.INITIAL
	start_room.has_enemies = false
	start_room.enemy_id = -1
	start_room.is_player_inside = true
	rooms[start_pos] = start_room

	# 2. 随机向四周扩展生成普通房间
	var room_positions: Array[Vector2] = [start_pos]
	var dir_keys = DIRECTIONS.keys()

	while rooms.size() < target_room_count:
		var current_pos: Vector2
		if CORRIDOR_BIAS > 0.0 and randf() < CORRIDOR_BIAS:
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
			new_room.has_enemies = false
			new_room.enemy_id = -1
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

	# 4. 根据蓝图规则分配房间类型与敌人 ID
	_populate_enemies_and_types(rooms, blueprint)

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

#region 敌人生成与房间配置
## 填充房间类型与各级敌人 ID
func _populate_enemies_and_types(rooms: Dictionary, blueprint: MapBlueprint) -> void:
	var start_pos := Vector2.ZERO
	var available_positions: Array[Vector2] = []
	
	for pos in rooms.keys():
		if pos != start_pos:
			available_positions.append(pos)
			# 加权计算房间类型（目前主要为普通房）
			rooms[pos].room_type = _roll_room_type(blueprint.room_type_weights)

	# 1. 优先提取 Boss 房（BFS 拓扑最深 + 死胡同优先 + 跨主分支隔离）
	var boss_positions := _pick_boss_positions(rooms, blueprint.boss_count)
	for b_pos in boss_positions:
		var boss_room: RoomData = rooms[b_pos]
		boss_room.has_enemies = true
		boss_room.enemy_id = _fetch_enemy_id_by_level(2)
		available_positions.erase(b_pos)

	# 2. 剩余普通房间按概率分配常规敌人（0 级普通怪 / 1 级精英怪）
	for r_pos in available_positions:
		var room: RoomData = rooms[r_pos]
		if randf() < blueprint.enemy_spawn_chance:
			var target_level = 1 if (randf() < blueprint.elite_chance) else 0
			room.has_enemies = true
			room.enemy_id = _fetch_enemy_id_by_level(target_level)
		else:
			room.has_enemies = false
			room.enemy_id = -1


## Boss 选址算法：BFS 深度、死胡同加权与主分支隔离
func _pick_boss_positions(rooms: Dictionary, count: int) -> Array[Vector2]:
	var start_pos := Vector2.ZERO
	var depth_map: Dictionary = { start_pos: 0 }
	var branch_map: Dictionary = { start_pos: Vector2.ZERO }
	var queue: Array[Vector2] = [start_pos]

	# BFS 广度优先搜索并记录每个房间的一级分支来源
	while not queue.is_empty():
		var curr = queue.pop_front()
		var curr_depth: int = depth_map[curr]
		var curr_room: RoomData = rooms[curr]

		for dir in curr_room.connected_doors:
			var neighbor: Vector2 = curr + DIRECTIONS[dir]
			if rooms.has(neighbor) and not depth_map.has(neighbor):
				depth_map[neighbor] = curr_depth + 1
				branch_map[neighbor] = neighbor if curr == start_pos else branch_map[curr]
				queue.append(neighbor)

	# 综合打分：步数加权 + 死胡同高额加权
	var candidates: Array[Dictionary] = []
	for pos in rooms.keys():
		if pos == start_pos:
			continue
		var room: RoomData = rooms[pos]
		var is_dead_end: bool = (room.connected_doors.size() == 1)
		var score: int = depth_map.get(pos, 0) * 10 + (60 if is_dead_end else 0)
		candidates.append({
			"pos": pos,
			"score": score,
			"branch": branch_map.get(pos, Vector2.ZERO)
		})

	# 按评级分数降序排序
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])

	# 抽取 Boss 房间：优先选择未占用的不同分支
	var chosen: Array[Vector2] = []
	var used_branches: Array[Vector2] = []
	var take_target := mini(count, candidates.size())

	# 第一轮：跨分支优先挑选
	for item in candidates:
		if chosen.size() >= take_target:
			break
		if not item["branch"] in used_branches:
			chosen.append(item["pos"])
			used_branches.append(item["branch"])

	# 第二轮：若分支耗尽仍未达配额，按评分补齐
	if chosen.size() < take_target:
		for item in candidates:
			if chosen.size() >= take_target:
				break
			if not item["pos"] in chosen:
				chosen.append(item["pos"])

	return chosen


## 从 AllEnemyData 单例池中按等级抽取一个敌人 ID
func _fetch_enemy_id_by_level(target_level: int) -> int:
	var enemy_dict: Dictionary = AllEnemyData.get_all_enemy_data()
	var matching_ids: Array[int] = []

	for e_id in enemy_dict.keys():
		var enemy: EnemyData = enemy_dict[e_id]
		if enemy and enemy.enemy_level == target_level:
			matching_ids.append(int(e_id))

	if matching_ids.is_empty():
		push_warning("WorldGenerator: 未找到等级为 %d 的敌人 ID！" % target_level)
		return -1

	return matching_ids.pick_random()


## 根据权重字典随机返回房间类型
func _roll_room_type(weights: Dictionary) -> RoomData.RoomType:
	var total_weight: int = 0
	for w in weights.values():
		total_weight += int(w)

	if total_weight <= 0:
		return RoomData.RoomType.NORMAL

	var roll := randi_range(1, total_weight)
	var accumulated := 0
	for r_type in weights.keys():
		accumulated += int(weights[r_type])
		if roll <= accumulated:
			return r_type

	return RoomData.RoomType.NORMAL
#endregion
