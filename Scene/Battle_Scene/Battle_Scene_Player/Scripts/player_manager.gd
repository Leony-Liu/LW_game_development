# player_manager
# 
# 玩家卡牌入口

extends Node

# 绑定玩家数据与状态系统
@onready var combat_data = $Data/CombatData
@onready var state_machine = %StateMachine


# 玩家系统卡牌入口：出牌状态反馈
func execute_card(card_data: Dictionary) -> bool:
	if state_machine.handle_card_played(card_data):
		print("玩家管理器：出牌成功")
		return true
	else:
		print("玩家管理器：出牌失败")
		return false
	
