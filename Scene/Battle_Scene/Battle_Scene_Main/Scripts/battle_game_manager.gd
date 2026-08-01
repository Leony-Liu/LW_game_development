extends Node
class_name BattleGameManager


# 绑定玩家和敌人列表子节点
@export var player :Node3D
@export var enemy_slot :Node

var current_enemy: Node = null # 当前敌人



# 接收外部信号：出牌
# 接收系统内信号：玩家、敌人伤害
func _ready() -> void:
	
	BattleBus.card_played.connect(_on_card_played) # 接收出牌信号
	BattleBus.player_dealt_damage.connect(_on_player_dealt_damage)# 接收玩家发出的总伤害
	BattleBus.enemy_dealt_damage.connect(_on_enemy_dealt_damage)# 接收敌人发出的总伤害
	
	_register_current_enemy()


# 登记敌人列表的第一个敌人
func _register_current_enemy():
	if enemy_slot.get_child_count() > 0:
		current_enemy = enemy_slot.get_child(0)
		print("battle_game_manager：已登记当前敌人 -> ", current_enemy.name)
	else:
		current_enemy = null


# ==========================================
# 玩家出牌许可判定
# ==========================================

# 出牌许可环境判断
func can_play_card(card_data: Dictionary) -> bool:
	
	if card_data.has("categories") and card_data["categories"] == "attack":
		# 若无当前敌人无法出牌
		if current_enemy == null:
			return false
			
		# 获取状态机
		var sm = current_enemy.get_node_or_null("StateMachine")
		
		## 安全判定：状态机节点存在 -> 状态机脚本上有 current_state 属性 -> 且该属性不为空
		#if sm and "current_state" in sm and sm.current_state != null:
			#var enemy_state = sm.current_state.name
			## 判定敌人是否在无敌状态
			#if enemy_state in ["Burrowed", "Invincible"]: 
				#return false
				#
	return true

# 出牌执行
func _on_card_played(
	card_data: Dictionary,
	card_node: Control
) -> void:
	if not can_play_card(card_data):
		BattleBus.card_rejected.emit(
			card_node,
			&"invalid_target"
		)
		return

	var action := _create_player_timeline_action(card_data)

	if action == null:
		BattleBus.card_rejected.emit(
			card_node,
			&"invalid_action_data"
		)
		return

	BattleBus.action_require.emit(action)

	BattleBus.card_successfully_played.emit(
		card_data,
		card_node
	)

# 卡牌数据转换
func _create_player_timeline_action(
	card_data: Dictionary
) -> TimelineAction:
	var action := TimelineAction.new()

	action.action_name = StringName(
		str(card_data.get("id", ""))
	)

	action.action_name = str(
		card_data.get("name_key", "")
	)

	action.actor = player
	action.actor_side = TimelineAction.ActorSide.PLAYER

	action.time_cost = int(
		card_data.get("time_cost", 0)
	)

	action.action_speed = int(
		card_data.get("action_speed", 1)
	)

	action.advances_time = true
	action.can_be_cancelled = true

	# 保存出牌这一刻的卡牌数据副本
	action.payload = card_data.duplicate(true)

	return action

# ==========================================
# 双方伤害中转站
# ==========================================

# 1. 接收玩家攻击信号后：并转发给当前敌人
func _on_player_dealt_damage(payload: Dictionary) -> void:
	# 判定是否有敌人，且挂载受伤方法
	if current_enemy and current_enemy.has_method("take_damage"):
		print("battle_game_manager：收到玩家伤害包，直接路由给当前敌人...")
		# 执行敌人的受伤方法
		current_enemy.take_damage(payload)
		
	else:
		print("battle_game_manager：伤害打空了！")

# 2. 接收玩家攻击信号后：并转发给当前敌人
func _on_enemy_dealt_damage(payload: Dictionary) -> void:
	# 判断是否有玩家，且玩家有数据
	if player and player.has_node("Data/CombatData"):
		print("battle_game_manager：收到敌人攻击包，路由给玩家...")
		# 连接玩家数据脚本
		var p_combat_data = player.get_node("Data/CombatData")
		# 执行玩家数据脚本内的受伤方法
		p_combat_data.get_hit(payload["damage"], payload["source"].name)
