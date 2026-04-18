#怪物巡逻状态
extends DungeonEnemyState

func enter():
	print("进入巡逻状态")

func physics_update(delat):
	var partrol_target = get_patrol_target()
	enemy.movement.move_to(partrol_target)
	machine.change_state("idle")
	pass



#巡逻坐标
func get_patrol_target()-> Vector2:
	if enemy.get_my_room() == null:
		return enemy.global_position
	
	var room = enemy.get_my_room().room
	var target_x = randf_range(room.position.x, room.end.x)
	var target_y = randf_range(room.position.y, room.end.y)
	var target_pos = Vector2i(target_x, target_y)
	var world_target_pos = enemy.get_my_tilemap().local_to_map(target_pos)
	return world_target_pos
