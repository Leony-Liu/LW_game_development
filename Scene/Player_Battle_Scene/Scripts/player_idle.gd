extends State


func enter(msg:Dictionary = {}) -> void:
	# 刚进入待机状态，立马播放待机动画
	host.get_node("Visuals/AnimationPlayer").play("player_idle")


func update(delta: float) -> void:
	# 待机状态下，每帧恢复资源
	host.get_node("Data/CombatData").stanima_recovery(delta)
	host.get_node("Data/CombatData").mana_recovery(delta)


# 出牌后切换状态
func handle_card_played(card_data: Dictionary) -> void:
	# 根据卡牌类型，决定去哪个状态
	if card_data["categories"] == "attack":
		get_parent().transition_to("Attack",{"card":card_data})
		
	# CSV表头，拆解数据库数据
	elif  card_data["categories"] == "skills":
		get_parent().transition_to("Skill",{"card":card_data})
