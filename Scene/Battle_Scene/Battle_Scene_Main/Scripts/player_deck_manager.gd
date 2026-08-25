extends Node

# 玩家牌组：ID加数量
@export var starter_deck_config: Dictionary = {
	10001: 2,
	10002: 2,
	10003: 2,
	10004: 2,
	10005: 2,
	20001: 2,
	20002: 2
}

var deck_ids: Array = [] # 玩家牌组

func _ready():
	generate_deck()

# 用上面字典的数据，塞数组里面
func generate_deck():
	deck_ids.clear()
	for card_id in starter_deck_config:
		var count = starter_deck_config[card_id]
		for i in range(count):
			deck_ids.append(card_id)
	print("手牌管理器：初始牌组生成完毕，共计: ", deck_ids.size(), " 张牌")

# C.提供给其他脚本获取牌组的方法
func get_deck():
	return deck_ids
