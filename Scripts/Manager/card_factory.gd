# 定义：卡牌工厂（单例）
# 作用：
# A.创建卡牌


extends Node

var basic_card_scene = preload("res://Scene/Card.tscn")# 预加载基础卡牌场景


#创建卡牌
func create_card(id: int) -> Node:
	# 1. 实例化基础卡牌场景
	var new_card = basic_card_scene.instantiate()
	# 2. 把 ID 塞给它
	# 假设card_base里面有一个变量叫作card_id
	if "card_id" in new_card:
		new_card.card_id = id
	# 3. 返回这个实例，让 CardManager 决定把它加到哪
	print("卡牌工厂：已实例化")
	return new_card
	
