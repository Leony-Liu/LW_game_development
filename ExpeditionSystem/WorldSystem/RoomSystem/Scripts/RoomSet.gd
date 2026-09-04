class_name RoomSet
extends Node3D

@export var battle_room_scene: PackedScene 
@export var room_size: float = 10.0

var map_grid: Dictionary = {} # 键: Vector2i, 值: RoomData
var _start_pos: Vector2i = Vector2i.ZERO

const DIRS = {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const OPPOSITE = {"N": "S", "E": "W", "S": "N", "W": "E"}

# 核心：根据种子推演数据并铺设实体
func generate_maze(rng_seed: int, target_count: int) -> void:
	# 清理旧数据和旧实体
	map_grid.clear()
	for child in get_children():
		child.queue_free()
		
	var rng = RandomNumberGenerator.new()
	rng.seed = rng_seed
	
	# 1. 纯数据推演（基于随机广度优先）
	var current_count = 0
	var active_coords: Array[Vector2i] = [_start_pos]
	
	var start_room = RoomData.new()
	start_room.grid_pos = _start_pos
	start_room.is_start_room = true
	map_grid[_start_pos] = start_room
	current_count += 1
	
	while current_count < target_count and active_coords.size() > 0:
		var center = active_coords[rng.randi() % active_coords.size()]
		var dir_keys = DIRS.keys()
		var expand_dir = dir_keys[rng.randi() % dir_keys.size()]
		var target_pos = center + DIRS[expand_dir]
		
		# 如果目标网格为空，则生成新房间
		if not map_grid.has(target_pos):
			var new_room = RoomData.new()
			new_room.grid_pos = target_pos
			# 30% 概率刷怪（测试用，后期可接入读表）
			new_room.has_enemy = rng.randf() < 0.3 
			new_room.enemy_id = 101 if new_room.has_enemy else -1
			
			map_grid[target_pos] = new_room
			active_coords.append(target_pos)
			current_count += 1
			
		# 打通两个房间之间的门
		if not map_grid[center].doors.has(expand_dir):
			map_grid[center].doors.append(expand_dir)
		if not map_grid[target_pos].doors.has(OPPOSITE[expand_dir]):
			map_grid[target_pos].doors.append(OPPOSITE[expand_dir])
			
	# 2. 实体铺设
	for pos in map_grid:
		var r_data = map_grid[pos]
		var room_instance = battle_room_scene.instantiate()
		add_child(room_instance)
		
		room_instance.position = Vector3(pos.x * room_size, 0, pos.y * room_size)
		# 假设 BattleRoom 有 initialize_room 方法来处理删墙和刷怪
		if room_instance.has_method("initialize_room"):
			room_instance.initialize_room(r_data)

# 供 WorldManager 询问通行状态
func can_move_to(current_pos: Vector2i, facing: String) -> bool:
	var current_room = map_grid.get(current_pos)
	if current_room and current_room.doors.has(facing):
		return true
	return false

func get_room_data(pos: Vector2i) -> RoomData:
	return map_grid.get(pos)

func get_start_room_pos() -> Vector2i:
	return _start_pos

# 销毁 3D 房间内的敌人模型
func clear_enemy_visual_in_room(pos: Vector2i) -> void:
	# 实体遍历匹配，根据 3D 坐标反推或者给房间打上 name 标签均可
	for child in get_children():
		var child_pos2d = Vector2i(round(child.position.x / room_size), round(child.position.z / room_size))
		if child_pos2d == pos:
			if child.has_method("clear_enemy_visual"):
				child.clear_enemy_visual()
			break
