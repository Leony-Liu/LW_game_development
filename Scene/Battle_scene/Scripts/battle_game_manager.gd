extends Node
class_name BattleGameManager


@onready var player_manager = $Player

# 记录当前玩家锁定的敌人
var current_target_enemy: Node = null 

func _ready() -> void:
	
	EventBus.card_played.connect(_on_card_played)# 接收出牌信号
	EventBus.player_dealt_damage.connect(_on_player_dealt_damage)# 接收计算完的总伤害

# 接收玩家伤害，并转发给当前敌人
func _on_player_dealt_damage(payload: Dictionary) -> void:
	# 确保当前有敌人
	if current_target_enemy != null:
		print("战斗管理器：收到玩家伤害包，正在路由给当前敌人...")
		
		# 假设敌人的根节点下有个 EnemyManager 来处理挨打逻辑
		# (根据你的节点结构，调用敌人身上对应的方法)
		if current_target_enemy.has_node("EnemyManager"):
			current_target_enemy.get_node("EnemyManager").take_damage(payload)
	else:
		print("战斗管理器：伤害打空了！当前场上没有敌人。")
		
		
# 卡牌拦截逻辑
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


# 裁判规则库 
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
