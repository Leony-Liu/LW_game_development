extends Node
class_name EnemyCalculator

@onready var combat_data: EnermyCombatData = $"../CombatData"

# 专门计算敌人挨打时，扣除防御后的【真实承受伤害】
func calculate_incoming_damage(incoming_dmg: int) -> int:
	# 极简防御公式：传入伤害 - 敌人防御力
	var real_damage = incoming_dmg - combat_data.enermy_defense
	
	# 保底：最少扣 1 点血，防止防御过高变回血
	real_damage = max(1, real_damage)
	
	return real_damage

# 以后如果敌人要打玩家，在这里写 calculate_outgoing_damage()
