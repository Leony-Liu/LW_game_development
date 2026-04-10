extends Node
class_name EnemyCalculator

@onready var combat_data: EnemyCombatData = $"../CombatData"

# 受伤减免计算
func calculate_incoming_damage(incoming_dmg: int) -> int:
	# 极简防御公式：传入伤害 - 敌人防御力
	var real_damage = incoming_dmg - combat_data.enemy_defense
	
	# 保底：最少扣 1 点血，防止防御过高变回血
	real_damage = max(1, real_damage)
	
	return real_damage

# 攻击增益计算
func calculate_outgoing_damage():
	pass
