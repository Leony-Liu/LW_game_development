# 定义：卡牌工厂（单例）
# 作用：
# A.创建卡牌

extends Node


# 修改为你的 2D 卡牌场景路径
var basic_card_scene = preload("res://Scene/Battle_Scene/Card_Scene/Card.tscn")

func create_card(id: int) -> Node:
	var new_card = basic_card_scene.instantiate()
	if "card_id" in new_card:
		new_card.card_id = id
	return new_card
	
