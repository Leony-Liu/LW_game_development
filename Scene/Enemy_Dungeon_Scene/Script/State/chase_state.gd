#怪物巡逻状态
extends DungeonEnemyState

var update_path_timer: float = 0.0
var lost_target_timer: float = 0.0

func enter():
	print("怪物进入追击状态")
	pass


#调用移动敌人组件
func physics_update(delta):
	var target = enemy.player_target
	if not target:
		lost_target_timer += delta
		if lost_target_timer > 0.08:
			print("怪物没有发现玩家")
			machine.change_state("patrol")
		return
		
	lost_target_timer = 0.0
	update_path_timer += delta
	if update_path_timer > 0.5:
		enemy.movement.set_target(target.global_position)
		enemy.anima_play("walk")
		print("怪物追击玩家")
		update_path_timer = 0.0
	enemy.movement.move_to(delta)
	
	var distance = enemy.global_position.distance_to(target.global_position)
	if distance < 10:
		machine.change_state("attack")


func exit():
	pass
#获取巡逻去向坐标
