# 定义：玩家管理器（单例）
# 作用：
#

extends Node


@onready var combat_data = $Data/CombatData
@onready var state_machine = $StateMachine

func _ready() -> void:
	EventBus.card_played.connect(_on_card_played)# 接收卡牌被打出的信号及其数据


# 将出牌信号传给状态交换机
func _on_card_played(card_data:Dictionary)->void:
	if state_machine.handle_card_played(card_data):
		print("玩家管理器：成功出牌")
	else :
		print("玩家管理器：当前状态不可出牌")
	
