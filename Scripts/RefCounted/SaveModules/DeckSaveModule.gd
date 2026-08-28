class_name DeckSaveModule
extends SaveModule

# 内存中真实的牌组数据存放处
var current_deck: Array[CardInstance] = []

# 定义在 JSON 里的键名。日后升级武器系统时，可以把这里改成 "weapons"
func get_module_key() -> String:
	return "player_deck" 

# --- 存档逻辑 ---
func get_save_data() -> Array:
	var deck_data = []
	for card in current_deck:
		deck_data.append(card.to_dict())
	return deck_data

# --- 读档逻辑 ---
func load_save_data(data):
	current_deck.clear()
	# 假设 data 是从 JSON 读出来的数组
	if data is Array:
		for card_dict in data:
			var card_inst = CardInstance.from_dict(card_dict)
			if card_inst != null:
				current_deck.append(card_inst)
	print("[DeckSaveModule] 牌组读取完毕，共加载了 %d 张牌。" % current_deck.size())

# --- 供测试用的快捷方法 ---
func build_test_deck():
	current_deck.clear()
	# 塞入两张基础重劈 (假设ID为1001)
	current_deck.append(CardInstance.new(1001))
	current_deck.append(CardInstance.new(1001))
	
	# 塞入一张强化过的重劈
	var upgraded = CardInstance.new(1001)
	upgraded.modifiers.append({"type": "damage_up", "value": 15})
	current_deck.append(upgraded)
