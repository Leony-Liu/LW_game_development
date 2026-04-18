#怪物站立状态
extends DungeonEnemyState

var timer: float
func enter():
	timer = 0.0
	enemy.play_animation("Idle")
	enemy.movement.move_stop()
	pass


func physics_update(delta):
	timer += delta
	
	if enemy.get_detected_player():
		machine.change_state("chase")
		return
	
	#待机时长，后面建议可以传入随机的待机时间
	if timer > 3.0:
		machine.change_state("patrol")
		return


func exit():
	pass
