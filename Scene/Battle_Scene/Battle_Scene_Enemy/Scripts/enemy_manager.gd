# enemy_manager
#
# 敌人初始化
# 玩家伤害处理

extends Node
class_name EnemyManager


# 在场景里暴露给策划或地牢生成器配置
@export var enemy_tier: int = 1 # 敌人等级
@export var mechanic_count: int = 2 # 机制数量


@onready var combat_data: EnemyCombatData = %CombatData
@onready var calculator: EnemyCalculator = %Calculator
@onready var state_machine = %StateMachine
@onready var ai_brain = %EnemyAIBrain

# ==========================================
# 敌人初始化
# ==========================================

func _ready() -> void:
	print("====== 敌人装配开始 ======")
	print("当前敌人阶级: Tier ", enemy_tier)
	
	# 输入怪物等级和机制数量并调用抽取方法
	var rolled_mechanics = MechanicDatabaseManager.roll_mechanics_for_tier(enemy_tier, mechanic_count)
	
	# 拿到的机制传输到AI大脑
	if rolled_mechanics.size() > 0:
		ai_brain.initialize(rolled_mechanics)
	else:
		print("注意：该敌人没有抽到任何机制。")
		
	print("==========================")

# ==========================================
# 玩家伤害处理
# ==========================================
# 接收玩家的伤害
func take_damage(payload: Dictionary) -> void:
	var incoming_dmg = payload["damage"]
	var dmg_type = payload["type"]
	
	#  扔给计算器算真实伤害
	var real_damage = calculator.calculate_incoming_damage(incoming_dmg)
	
	#  扔给 CombatData 去扣血
	combat_data.get_hit(real_damage, "player_attack")
