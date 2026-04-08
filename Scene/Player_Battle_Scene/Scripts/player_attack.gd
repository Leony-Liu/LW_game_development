extends State

var card_data:Dictionary

func enter(msg:Dictionary = {}) -> void:
	
	if msg.has("card"):
		card_data  = msg["card"]
	
	host.get_node("Visuals/AnimationPlayer").play("player_attack")
