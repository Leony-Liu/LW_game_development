class_name WorldGenerator
extends RefCounted

# 四个方向的坐标偏移量与反向映射
const DIRS = {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const OPPOSITE = {"N": "S", "E": "W", "S": "N", "W": "E"}

var _start_pos: Vector2i = Vector2i.ZERO

# 获取本次生成的玩家出生房间坐标
func get_start_room_pos() -> Vector2i:
	return _start_pos

# 输入种子和目标房间数，计算出所有房间的网格坐标、门的位置和怪物数据
func generate_map_data(rng_seed: int, target_count: int) -> Dictionary:
	var map_grid: Dictionary = {}
	var rng = RandomNumberGenerator.new()
	rng.seed = rng_seed
	
	# 创建起始房间（坐标固定为 0,0，不刷怪）
	var start_room = RoomData.new()
	start_room.grid_pos = _start_pos
	start_room.is_start_room = true
	map_grid[_start_pos] = start_room
	
	# 记录已生成的房间坐标，用来作为后续向外扩张的基准点
	var active_coords: Array[Vector2i] = [_start_pos]
	var current_count: int = 1
	var dir_keys = DIRS.keys()
	
	# 循环随机抽选已有房间并向外扩张，直到房间数量达标
	while current_count < target_count and active_coords.size() > 0:
		var center = active_coords[rng.randi() % active_coords.size()]
		var expand_dir = dir_keys[rng.randi() % dir_keys.size()]
		var target_pos = center + DIRS[expand_dir]
		
		# 目标网格没有房间时，创建新房间数据
		if not map_grid.has(target_pos):
			var new_room = RoomData.new()
			new_room.grid_pos = target_pos
			
			# 30% 概率标记有敌人
			new_room.has_enemy = rng.randf() < 0.3
			new_room.enemy_id = 101 if new_room.has_enemy else -1
			
			map_grid[target_pos] = new_room
			active_coords.append(target_pos)
			current_count += 1
		
		# 在当前房间和目标房间之间双向记录开门方向
		if not map_grid[center].doors.has(expand_dir):
			map_grid[center].doors.append(expand_dir)
		if not map_grid[target_pos].doors.has(OPPOSITE[expand_dir]):
			map_grid[target_pos].doors.append(OPPOSITE[expand_dir])
			
	return map_grid
