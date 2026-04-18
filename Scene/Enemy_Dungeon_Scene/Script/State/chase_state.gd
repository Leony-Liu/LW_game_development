#怪物巡逻状态
extends DungeonEnemyState

#调用移动敌人组件
func physics_updata():
	var target = enemy.player_target
	
	if target:
		enemy.movement.move_to(target.global_position)
	else:
		machine.change_state("patrol")#目标丢失，切换巡逻状态

#获取巡逻去向坐标
