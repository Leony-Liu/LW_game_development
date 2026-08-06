# player_idle
#
# 待机体力、能量恢复 | 格挡功能的启发点
# 核验出牌资源

extends State

@onready var visuals = $"../../PlayerVisuals/Visuals/player_3Dvisuals"

# 进入本状态后立刻执行
func enter(msg:Dictionary = {}) -> void:
	
	print("玩家进入状态：Idle")
	# 获取视觉管理器并播放动画
	if visuals and visuals.has_method("play_idle"):
		visuals.play_idle()
	

# ==========================================
# 待机体力、能量恢复 | 格挡功能的启发点
# ==========================================

# 在本状态内每帧执行
func update(_delta: float) -> void:
	# 资源不再按照现实帧恢复。

	pass

# ==========================================
# 核验出牌资源
# ==========================================

# 出牌前的资源核验
# 注意：先返回 bool 值给状态机，再传给裁判
func handle_card_played(card_data: Dictionary) -> bool:
	# 连接玩家数据
	var combat_data = host.get_node("Data/CombatData")
	
	# a. 攻击牌：核验体力
	if card_data["categories"] == "attack":
		var cost = card_data.get("stamina_cost", 1) # 默认消耗1点防错
		# 成功扣除后进入攻击状态
		if combat_data.consume_stamina(cost):
			print("待机状态：体力扣除成功，切入 Attack 状态")
			get_parent().transition_to("Attack", {"card": card_data})
			return true
		else:
			print("待机状态：体力不足！拒绝出牌。")
			return false
			
	# b. 技能牌：核验能量
	elif card_data["categories"] == "skill":
		var cost = card_data.get("mana_cost", 1) # 默认消耗1点防错
		# 成功扣除后进入技能状态
		if combat_data.consume_mana(cost):
			print("待机状态：能量扣除成功，切入 Skill 状态")
			get_parent().transition_to("Skill", {"card": card_data})
			return true
		else:
			print("待机状态：能量不足！拒绝出牌。")
			return false
			
	# 兜底：如果卡牌类型没写对
	print("待机状态：未知的卡牌类型，拒绝执行")
	return false
