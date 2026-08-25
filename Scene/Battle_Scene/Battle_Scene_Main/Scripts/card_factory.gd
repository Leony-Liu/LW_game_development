
extends Node


# 修改为你的 2D 卡牌场景路径
@export var basic_card_scene : PackedScene 

func create_card(id: int) -> Node:
	var new_card = basic_card_scene.instantiate()
	if "card_id" in new_card:
		new_card.card_id = id
	return new_card
	
