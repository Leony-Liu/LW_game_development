extends Node
class_name EnemyManager


# 在场景里暴露给策划或地牢生成器配置
@export var enemy_tier: int = 1 
@export var mechanic_count: int = 2 # 这个怪身上要插几个机制芯片？


@onready var combat_data: EnemyCombatData = $Data/CombatData
@onready var calculator: EnemyCalculator = $Data/Calculator
@onready var state_machine = $StateMachine
@onready var ai_brain = $EnemyAIBrain


func _ready() -> void:
	print("====== 敌人装配开始 ======")
	print("当前敌人阶级: Tier ", enemy_tier)
	
	# 抽取机制
	var rolled_mechanics = MechanicDatabaseManager.roll_mechanics_for_tier(enemy_tier, mechanic_count)
	
	# 拿到机制名字的数组（比如 ["buff_defence", "double_attack"]），扔给大脑去装配
	if rolled_mechanics.size() > 0:
		ai_brain.initialize(rolled_mechanics)
	else:
		print("注意：该敌人没有抽到任何机制。")
		
	print("==========================")


# 接收玩家的伤害
func take_damage(payload: Dictionary) -> void:
	var incoming_dmg = payload["damage"]
	var dmg_type = payload["type"]
	
	# 1. 扔给计算器算真实伤害
	var real_damage = calculator.calculate_incoming_damage(incoming_dmg)
	
	# 2. 扔给状态机去播放“受击动画/硬直” (假设你在状态机里写了这个方法)
	state_machine.transition_to("Hurt")
	
	# 3. 扔给 CombatData 去扣血
	combat_data.get_hit(real_damage, "player_attack")
