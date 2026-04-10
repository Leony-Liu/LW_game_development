# player_idle.gd
extends State

func enter(msg:Dictionary = {}) -> void:
	print("玩家：回到待机状态")
	# host.get_node("Visuals/AnimationPlayer").play("player_idle")

func update(delta: float) -> void:
	# 待机状态下，每帧恢复资源
	host.get_node("Data/CombatData").stanima_recovery(delta)
	host.get_node("Data/CombatData").mana_recovery(delta)
	
	# 如果检测到按住了空格键，立刻切入格挡状态
	if Input.is_action_pressed("block_key"):
		get_parent().transition_to("Parry")


# 【核心修改】：出牌前的资源核验（收费站）
# 注意：这里需要返回 bool 值给状态机，再传给裁判
func handle_card_played(card_data: Dictionary) -> bool:
	var combat_data = host.get_node("Data/CombatData")
	
	# ------------------------------------
	# 分支 1：攻击类卡牌 (消耗体力)
	# ------------------------------------
	if card_data["categories"] == "attack":
		var cost = card_data.get("stanima_cost", 1) # 默认消耗1点防错
		
		if combat_data.consume_stanima(cost):
			print("待机状态：体力扣除成功，切入 Attack 状态")
			get_parent().transition_to("Attack", {"card": card_data})
			return true
		else:
			print("待机状态：体力不足！拒绝出牌。")
			return false
			
	# ------------------------------------
	# 分支 2：技能类卡牌 (消耗能量)
	# ------------------------------------
	elif card_data["categories"] == "skills":
		var cost = card_data.get("mana_cost", 1) # 默认消耗1点防错
		
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
