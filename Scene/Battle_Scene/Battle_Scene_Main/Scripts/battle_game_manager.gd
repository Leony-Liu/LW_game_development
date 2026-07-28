extends Node
class_name BattleGameManager


# 绑定玩家和敌人列表子节点
@export var player :Node3D
@export var enemy_slot :Node

var current_enemy: Node = null # 当前敌人

# 接收外部信号：出牌
# 接收系统内信号：玩家、敌人伤害
func _ready() -> void:
	
	BattleBus.card_played.connect(_on_card_played)# 接收出牌信号
	BattleBus.player_dealt_damage.connect(_on_player_dealt_damage)# 接收玩家发出的总伤害
	BattleBus.enemy_dealt_damage.connect(_on_enemy_dealt_damage)# 接收敌人发出的总伤害
	
	_register_current_enemy()


# 登记敌人列表的第一个敌人
func _register_current_enemy():
	if enemy_slot.get_child_count() > 0:
		current_enemy = enemy_slot.get_child(0)
		print("战斗裁判：已登记当前敌人 -> ", current_enemy.name)
	else:
		current_enemy = null


# ==========================================
# 玩家出牌许可判定
# ==========================================

# 1. 出牌许可环境判断：没有敌人/敌人无敌
func can_play_card(card_data: Dictionary) -> bool:
	
	if card_data.has("categories") and card_data["categories"] == "attack":
		# 若无当前敌人无法出牌
		if current_enemy == null:
			return false
			
		# 获取状态机
		var sm = current_enemy.get_node_or_null("StateMachine")
		
		# 安全判定：状态机节点存在 -> 状态机脚本上有 current_state 属性 -> 且该属性不为空
		if sm and "current_state" in sm and sm.current_state != null:
			var enemy_state = sm.current_state.name
			# 判定敌人是否在无敌状态
			if enemy_state in ["Burrowed", "Invincible"]: 
				return false
				
	return true

# 2. 判定与退回执行
func _on_card_played(card_data: Dictionary, card_node: Control) -> void:
	# 环境许可失败
	if not can_play_card(card_data):
		print("战斗裁判：出牌失败！目标无效或处于特殊状态。")
		BattleBus.card_rejected.emit(card_node)
		return
	# 内部状态判定
	if player.execute_card(card_data):
		print("战斗裁判：出牌成功")
		# 【修改点】：不再直接 queue_free()，而是发送信号让卡牌管理器接管
		BattleBus.card_successfully_played.emit(card_node)
	else:
		print("战斗裁判：卡牌被拦截，出牌失败")
		BattleBus.card_rejected.emit(card_node)


# ==========================================
# 双方伤害中转站
# ==========================================

# 1. 接收玩家攻击信号后：并转发给当前敌人
func _on_player_dealt_damage(payload: Dictionary) -> void:
	# 判定是否有敌人，且挂载受伤方法
	if current_enemy and current_enemy.has_method("take_damage"):
		print("战斗裁判：收到玩家伤害包，直接路由给当前敌人...")
		# 执行敌人的受伤方法
		current_enemy.take_damage(payload)
		
	else:
		print("战斗裁判：伤害打空了！")

# 2. 接收玩家攻击信号后：并转发给当前敌人
func _on_enemy_dealt_damage(payload: Dictionary) -> void:
	# 判断是否有玩家，且玩家有数据
	if player and player.has_node("Data/CombatData"):
		print("战斗裁判：收到敌人攻击包，路由给玩家...")
		# 连接玩家数据脚本
		var p_combat_data = player.get_node("Data/CombatData")
		# 执行玩家数据脚本内的受伤方法
		p_combat_data.get_hit(payload["damage"], payload["source"].name)
