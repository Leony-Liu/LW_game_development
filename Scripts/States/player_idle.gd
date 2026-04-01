extends State


func enter() -> void:
	# 刚进入待机状态，立马播放待机动画
	# 注意：这里的 player 就是大管家 state_machine.gd 里传过来的 owner（也就是根节点）
	host.get_node("Visuals/AnimationPlayer").play("player_idle")


func update(delta: float) -> void:
	# 待机状态下，每帧恢复资源
	# 假设你的 player 根节点有一个名为 combat_data 的子节点或变量
	host.get_node("Data/CombatData").stanima_recovery(delta)
	host.get_node("Data/CombatData").mana_recovery(delta)


# 假设玩家打出了一张牌，UI 把信号传给了主角，主角转发给当前状态
func handle_card_played(card_data: Dictionary) -> void:
	# 根据卡牌类型，决定去哪个状态
	if card_data["categories"] == "attack":
		get_parent().transition_to("Attack")
		
	# CSV表头，拆解数据库数据
	elif  card_data["categories"] == "skills":
		get_parent().transition_to("Skill")
