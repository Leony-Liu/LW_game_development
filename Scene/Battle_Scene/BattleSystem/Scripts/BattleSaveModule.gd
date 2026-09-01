class_name BattleSaveModule
extends SaveModule

# --- 战斗系统外输入的预留通道 ---
var input_deck = [] 
var input_player_data: EntityData 
var input_enemy_data: EntityData 

# --- 保存至战斗系统内的实际流通数据 ---
var current_deck : Array[RuntimeCard] = []

# 定义在 JSON 里的键名
func get_module_key() -> String:
	return "battle_state" 

func get_save_data() -> Array:
	var deck_data = []
	for card in current_deck:
		if card.has_method("to_dictionary"):
			deck_data.append(card.to_dictionary())
		else:
			deck_data.append({
				"card_id": card.card_id,
				"card_data": card.card_data
			})
	return deck_data

func load_save_data(data):
	input_deck.clear()
	current_deck.clear()
	
	if data is Array:
		for card_dictionary in data:
			var c_id = card_dictionary.get("card_id", 0)
			var c_data = card_dictionary.get("card_data", {})
			if c_id != 0:
				current_deck.append(RuntimeCard.new(c_id, c_data))
				
	print("[BattleSaveModule] 牌组读取完毕。")

#region 向核心统筹器(BattleManager)提供初始化数据

# 1. 提供卡牌数据
func process_and_get_runtime_deck() -> Array[RuntimeCard]:
	if not input_deck.is_empty():
		_compile_input_to_runtime()
	
	if current_deck.is_empty():
		push_warning("[BattleSaveModule] 警告：没有可用牌组，正在生成测试牌组...")
		build_test_deck()
		
	return current_deck

# 2. 提供玩家实体数据
func process_and_get_player_data() -> EntityData:
	if input_player_data:
		return input_player_data
		
	push_warning("[BattleSaveModule] 警告：无局外传入的玩家数据，生成测试玩家数据...")
	return build_test_player_data()

# 3. 提供敌人实体数据
func process_and_get_enemy_data() -> EntityData:
	if input_enemy_data:
		return input_enemy_data
		
	push_warning("[BattleSaveModule] 警告：无局外传入的敌人数据，生成测试敌人数据...")
	return build_test_enemy_data()

#endregion

# --- 预留：将局外的 CardInstance 转译为局内的 RuntimeCard ---
func _compile_input_to_runtime() -> void:
	current_deck.clear()
	var card_database = AllCardData.get_cards()
	
	for instance in input_deck:
		# TODO: 待 CardInstance 完善后，将其拆解并组装为 RuntimeCard
		pass

#region 测试数据生成器
func build_test_deck():
	current_deck.clear()
	var card_database = AllCardData.get_cards()
	
	# 测试的卡牌
	var test_card_ids: Array[int] = [1001, 1001, 1002, 1002] 
	
	for card_id in test_card_ids:
		if card_database.has(card_id):
			var new_card = RuntimeCard.new(card_id, card_database[card_id])
			current_deck.append(new_card)
		else:
			push_error("生成测试牌组警告：找不到 ID 为 %d 的卡牌资源！" % card_id)
			
	print("[BattleSaveModule] 测试牌组构建完毕，当前拥有卡牌数：", current_deck.size())

# 生成玩家测试数据：血量和发牌所需的费用（体力）
func build_test_player_data() -> EntityData:
	return EntityData.new("player_test", {
		"hp": 100.0,
		"stamina": 5.0,
		"max_stamina": 5.0
	})

# 生成敌人测试数据
func build_test_enemy_data() -> EntityData:
	return EntityData.new("enemy_test", {
		"hp": 80.0
	})
#endregion
