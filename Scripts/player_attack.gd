extends State

func enter() -> void:
	# 刚进入待机状态，立马播放待机动画
	host.get_node("Visuals/AnimationPlayer").play("player_attack")
