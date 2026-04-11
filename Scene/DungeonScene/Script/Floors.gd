#地牢层级管理器
extends Node2D

@export var dungeon_scene: PackedScene
@export var player_scene: PackedScene
@export var total_floors: int
@export var master_seed: int

func _ready() -> void:
	generate_all_floors()


func generate_all_floors():
	var rng = RandomNumberGenerator.new()
	rng.seed = master_seed
	
	for i in total_floors:
		var new_dungeon = dungeon_scene.instantiate()
		add_child(new_dungeon)
		new_dungeon.position.y = i * 5000
		var floor_seed = rng.randi()
		
		var manager = new_dungeon.get_node("TotalityManager")
		manager.setup_and_generate(floor_seed)
		
		if i == 0:
			spawn_player(manager)


func spawn_player(birth_floor: Node):
	var birth_node = null
	for node in birth_floor.leaf_node:
		if node.room_type == 0:
			birth_node = node
			break
	
	if birth_node and player_scene:
		var player = player_scene.instantiate()
		add_child(player)
		var tilemap = birth_floor.dungeon_logic.tilemap
		var local_pos = tilemap.map_to_local(birth_node.room.get_center())
		player.global_position = birth_floor.to_global(local_pos)
		
		print("地牢层级管理器：玩家已在第一层出生")
	else:
		print("地牢层级管理器：玩家未找到出生点")
	pass
