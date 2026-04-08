extends State

var card_data:Dictionary

func enter(msg:Dictionary = {}) -> void:
	if msg.has("card"):
		card_data  = msg["card"]
	# 刚进入待机状态，立马播放待机动画
	host.get_node("Visuals/AnimationPlayer").play("player_attack")
