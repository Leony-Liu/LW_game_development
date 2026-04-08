# 定义：玩家管理器（单例）
# 作用：
#

extends Node


@onready var combat_data = $Data/CombatData
@onready var state_machine = $StateMachine




# 将出牌信号传给状态交换机
func execute_card(card_data: Dictionary) -> bool:
	if state_machine.handle_card_played(card_data):
		print("玩家管理器：成功出牌")
		return true
	else:
		print("玩家管理器：当前状态不可出牌")
		return false
	
