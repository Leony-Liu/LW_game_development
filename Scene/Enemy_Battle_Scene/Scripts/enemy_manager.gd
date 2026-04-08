
extends Node

# 指向敌人自己的数据模块 (路径请根据你的实际情况调整，比如 $"../Data/EnemyCombatData")
@onready var combat_data: EnermyCombatData = $Data/CombatData

# 接收裁判传来的伤害包
func take_damage(payload: Dictionary) -> void:
	var incoming_dmg = payload["damage"]
	var dmg_type = payload["type"]
	
	# 极简的敌人受击计算：基础伤害 - 敌人防御力
	var real_damage = incoming_dmg - combat_data.enermy_defense
	
	# 伤害保底，防止防御太高导致加血
	real_damage = max(1, real_damage) 
	
	# 扣血
	combat_data.enermy_hp -= real_damage
	
	print("=======================================")
	print("敌人受击：受到 %d 点[%s]伤害！(已扣除防御 %d)" % [real_damage, dmg_type, combat_data.enermy_defense])
	print("敌人血量：剩余 %d " % combat_data.enermy_hp)
	print("=======================================")
	
	# 死亡检测
	if combat_data.enermy_hp <= 0:
		die()

func die() -> void:
	print("敌人：被击败")
	
	EventBus.enemy_died.emit(owner)
	owner.queue_free() # 销毁敌人节点
