#怪物巡逻状态
extends DungeonEnemyState

var partrol_target: Vector2
var my_map_info: MapInfo

func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	my_map_info = enemy.get_my_mapInfo()

func enter():
	print("进入巡逻状态")
	partrol_target = get_patrol_target()
	enemy.movement.set_target(partrol_target)
	print("获取巡逻坐标:", partrol_target)

func physics_update(delat):
	enemy.movement.move_to(delat)
	if enemy.movement.path_index >= enemy.movement.current_path.size():
		machine.change_state("idle")
	#machine.change_state("idle")
	
	pass


#巡逻坐标
func get_patrol_target()-> Vector2:
	if enemy.get_my_room() == null:
		return enemy.global_position
	
	var tilemap = enemy.get_my_mapInfo().basic_tilemap
	var enemy_grid = tilemap.local_to_map(tilemap.to_local(enemy.global_position))
	var room = enemy.get_my_room().room
	var room_pos_x = room.position.x
	var room_pos_y = room.position.y
	var room_end_x = room.end.x
	var room_end_y = room.end.y
	
	var patrol_range = 5#当前位置±5的范围
	for i in range(20):
		var offset = Vector2i(randi_range(-patrol_range, patrol_range), randi_range(-patrol_range, patrol_range))
		var candidate = enemy_grid + offset
		if my_map_info.obstacle_cell.has(candidate): continue
		if my_map_info.wall_cell.has(candidate): continue
		return tilemap.map_to_local(candidate)
	return enemy.global_position
