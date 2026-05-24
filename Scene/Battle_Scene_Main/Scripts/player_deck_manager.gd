# 定义：卡包管理器
# 作用：
# A.输入想要的卡牌及其数量
# B.根据输入的数据生成牌组
# C.提供它人读取数据的方法

extends Node


# —————— A.输入 ——————
# TODO 暂时为手动设置牌组
@export var starter_deck_config: Dictionary = {
	10001: 5,
	10002: 3,
	20001: 2,
	20002: 2
}

# —————— B.参数及初始化 ——————
var deck_ids: Array = [] # 玩家牌组


func _ready():
	generate_deck()


# —————— 处理 ——————
# 根据配置生成牌组列表
func generate_deck():
	deck_ids.clear()
	for card_id in starter_deck_config:
		var count = starter_deck_config[card_id]
		for i in range(count):
			deck_ids.append(card_id)
	
	print("手牌管理器：初始牌组生成完毕，共计: ", deck_ids.size(), " 张牌")
	
	
	
# —————— 输出 ——————
# C.提供给其他脚本获取牌组的方法
func get_deck():
	return deck_ids
