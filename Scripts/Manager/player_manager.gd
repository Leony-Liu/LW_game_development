# 定义：玩家管理器（单例）
# 作用：
#

extends Node


@onready var combat_data = $Data/CombatData
@onready var state_machine = $StateMachine

func _ready() -> void:
	EventBus.card_played.connect(_on_card_played)


func _on_card_played(card_data:Dictionary)->void:
	# 判断状态条件是否满足
	if state_machine.current_state.name != "Idle":
		print("玩家管理器：不可出牌")
		return
		
	# CSV表头，拆解数据库数据
	var cost = card_data["stanima_cost"]
	var card_type = card_data["categories"] 
	
	# 根据combatdata方法返回的布尔值判定
	if combat_data.consume_stanima(cost):
		
		if card_type == "attack":
			state_machine.transition_to("Attack",{"card":card_data})
			
		elif  card_type == "skills":
			state_machine.transition_to("Skill",{"card":card_data})
			
		else :
			print("玩家管理器：扣除体力失败")
