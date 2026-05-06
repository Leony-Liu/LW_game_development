#地牢怪物生成器
extends Node2D
class_name enemy_set
var mySeed: RandomNumberGenerator
@export var enemy_constainer: Node2D
@export var tilemap: TileMapLayer
@export var manager: Node2D

@export var map_info: MapInfo

func pick_random_with_seed(array: Array, rng: RandomNumberGenerator):
	if array.is_empty(): return null
	
	var random_index = rng.randi_range(0, array.size() - 1)
	return array[random_index]


func spawn_enemies_in_rooms(leaf_node: Array[BSPNode], world_obstacle: Dictionary):
	for node in leaf_node:
		if not node.room_config: 
			print("地牢怪物生成器：没有数据，跳过该节点")
			continue
		else:
			var cfg = node.room_config
			var enemy_count = mySeed.randi_range(cfg.min_enemies, cfg.max_enemies)
			
			for i in range(enemy_count):
				if cfg.enemy_pool.size() > 0:
					var enemy_scene = pick_random_with_seed(cfg.enemy_pool, mySeed)
					var enemy = enemy_scene.instantiate()
					enemy.get_node("Information").MyNode = node
					enemy.get_node("Information").ID = mySeed.randi_range(20001, 2100)
					enemy.get_node("Information").map_info = map_info
					enemy.get_node("Information").mySeed = mySeed##
					add_child(enemy)
					enemy.add_to_group("Enemies")
					enemy.global_position = get_enemy_set_pos(node, world_obstacle)
					
	pass


func get_enemy_set_pos(node: BSPNode, obstacle_occ: Dictionary) -> Vector2:
	var room_rect = node.room
	var padding = 3
	var set_pos: Vector2i
	for i in range(100):
		var random_x = mySeed.randi_range(room_rect.position.x + padding, room_rect.end.x - padding)
		var random_y = mySeed.randi_range(room_rect.position.y + padding, room_rect.end.y - padding)
		var temp_set_pos = Vector2i(random_x, random_y)
		if not obstacle_occ.has(temp_set_pos):
			set_pos = temp_set_pos
			break
		else:
			continue
		
	var local = tilemap.map_to_local(set_pos)
	var offset = Vector2(tilemap.tile_set.tile_size)/2.0
	return tilemap.to_global(local - offset)
