#怪物站立状态
extends DungeonEnemyState

var timer: float
func enter():
	timer = randf_range(2.0, 3.0)
	enemy.anima_play("idle")
	enemy.movement.move_stop()
	print("进入待机状态")
	pass


func physics_update(delta):
	timer -= delta
	
	if enemy.get_detected_player():
		machine.change_state("chase")
		return
	
	#待机时长，后面建议可以传入随机的待机时间
	if timer <= 0:
		machine.change_state("patrol")
		return


func exit():
	pass
