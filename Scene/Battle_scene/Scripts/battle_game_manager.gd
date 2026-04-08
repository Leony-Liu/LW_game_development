extends Node
class_name BattleGameManager


@onready var player_manager = $Player

# 记录当前玩家锁定的敌人
var current_target_enemy: Node = null 

func _ready() -> void:
	# 1. 权力交接：现在由战斗裁判亲自监听全场的出牌信号
	EventBus.card_played.connect(_on_card_played)


# 2. 核心拦截逻辑
func _on_card_played(card_data: Dictionary) -> void:
	# 先进行外部规则验证
	if not can_play_card(card_data, current_target_enemy):
		print("战斗管理器：拦截！目标无效或处于特殊状态。")
		
		return
		
	# 外部规则通过，向下“命令”玩家去执行出牌
	if player_manager.execute_card(card_data):
		print("战斗管理器：允许出牌，玩家动作已执行。")
	else:
		print("战斗管理器：拦截！玩家处于硬直或非Idle状态，无法出牌。")
		# 通知UI把卡牌退回


# 3. 裁判规则库 
func can_play_card(card_data: Dictionary, target: Node) -> bool:
	# 基础规则示例：如果这张牌是攻击牌，但场上没有敌人，则不能打出
	if card_data.has("categories") and card_data["categories"] == "attack":
		if target == null:
			print("战斗管理器：没有可攻击的目标！")
			return false
			
		# 这里可以读取敌人的状态机，判断敌人是不是处于 "无敌" / "飞行" 状态
		# var enemy_state = target.get_node("StateMachine").current_state.name
		# if enemy_state == "Invincible": return false
		
	# 所有条件通过，放行
	return true
