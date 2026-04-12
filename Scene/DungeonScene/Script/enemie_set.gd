#地牢怪物生成器
extends Node2D
class_name enemy_set
var mySeed: RandomNumberGenerator
@export var enemy_constainer: Node2D
@export var tilemap: TileMapLayer

func pick_random_with_seed(array: Array, rng: RandomNumberGenerator):
	if array.is_empty(): return null
	
	var random_index = rng.randi_range(0, array.size() - 1)
	return array[random_index]


func spawn_enemies_in_rooms(leaf_node: Array[BSPNode]):
	for node in leaf_node:
		if not node.room_config: return
		
		var cfg = node.room_config
		var enemy_count = mySeed.randi_range(cfg.min_enemies, cfg.max_enemies)
		
		for i in range(enemy_count):
			if cfg.enemy_pool.size() > 0:
				var enemy_scene = pick_random_with_seed(cfg.enemy_pool, mySeed)
				var enemy = enemy_scene.instantiate()
				enemy.get_node("EnemyManager").MyNode = node
				add_child(enemy)
				enemy.global_position = get_enemy_set_pos(node)
	pass


func get_enemy_set_pos(node: BSPNode) -> Vector2:
	var room_rect = node.room
	var padding = 3
	var random_x = mySeed.randi_range(room_rect.position.x - padding, room_rect.end.x - padding)
	var random_y = mySeed.randi_range(room_rect.position.y - padding, room_rect.end.y - padding)
	var set_pos = Vector2i(random_x, random_y)
	return tilemap.map_to_local(set_pos)
