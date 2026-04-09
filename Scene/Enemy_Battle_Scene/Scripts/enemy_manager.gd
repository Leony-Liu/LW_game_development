extends Node
class_name EnemyManager

@onready var combat_data: EnermyCombatData = $Data/CombatData
@onready var calculator: EnemyCalculator = $Data/Calculator
@onready var state_machine = $StateMachine

# 接收裁判传来的伤害包
func take_damage(payload: Dictionary) -> void:
	var incoming_dmg = payload["damage"]
	var dmg_type = payload["type"]
	
	# 1. 扔给计算器算真实伤害
	var real_damage = calculator.calculate_incoming_damage(incoming_dmg)
	
	# 2. 扔给状态机去播放“受击动画/硬直” (假设你在状态机里写了这个方法)
	state_machine.transition_to("Hurt")
	
	# 3. 扔给 CombatData 去扣血
	combat_data.get_hit(real_damage, "player_attack")
