class_name BattleSaveModule
extends SaveModule

# --- 战斗状态标记 ---
var is_in_combat: bool = false
var rng_seed: int = 0

# --- 战斗系统外输入的预留通道 ---
var input_deck: Array = [CardInstance] 
var input_player_data: EntityData 
var input_enemy_data: EnemyData

# --- 保存至战斗系统内的实际流通数据 ---
var current_deck: Array[RuntimeCard] = []

#region 模块方法
# 定义在 JSON 里的键名
func get_module_key() -> String:
	return "battle_save" 

# 将战前所有状态打包成一个快照字典保存
func get_save_data() -> Dictionary:
	var deck_data = []
	for card in current_deck:
		if card.has_method("to_dictionary"):
			deck_data.append(card.to_dictionary())
		else:
			deck_data.append({"card_id": card.card_id, "card_data": card.card_data})
		print("[BattleSaveModule] 已打包 -牌组数据-")
		
	var player_dict = {}
	if input_player_data:
		player_dict = {"entity_id": input_player_data.entity_id, "base_attributes": input_player_data.base_attributes}
		print("[BattleSaveModule] 已打包 -玩家数据-")
	var enemy_dict = {}
	if input_enemy_data:
		enemy_dict = {
			"enemy_id": input_enemy_data.enemy_id, 
			"base_attributes": input_enemy_data.base_attributes
		}
		print("[BattleSaveModule] 已打包 -敌人数据-")

	return {
		"is_in_combat": is_in_combat,
		"rng_seed": rng_seed,
		"current_deck": deck_data,
		"player_data": player_dict,
		"enemy_data": enemy_dict
	}
	print("[BattleSaveModule] 所有已存储数据被读取")

# 读取存档恢复快照数据
func load_save_data(data: Variant) -> void:
	clear_data()
	if typeof(data) != TYPE_DICTIONARY:
		return
		
	is_in_combat = data.get("is_in_combat", false)
	rng_seed = data.get("rng_seed", 0)
	
	if data.has("current_deck") and data["current_deck"] is Array:
		for card_dict in data["current_deck"]:
			var c_id = card_dict.get("card_id", 0)
			var c_data = card_dict.get("card_data", {})
			if c_id != 0:
				current_deck.append(RuntimeCard.new(c_id, c_data))
				
	if data.has("player_data") and not data["player_data"].is_empty():
		input_player_data = EntityData.new(data["player_data"].get("entity_id", ""), data["player_data"].get("base_attributes", {}))
		

	if data.has("enemy_data") and not data["enemy_data"].is_empty():
		var saved_enemy_data = data["enemy_data"]
		var e_id = saved_enemy_data.get("enemy_id", -1)
		
		# 从数据库拉取包含动作池的完整模板
		var template = AllEnemyData.get_enemy(e_id)
		if template:
			input_enemy_data = template.duplicate(true)
			# 将存档中的残血状态覆盖上去
			input_enemy_data.base_attributes = saved_enemy_data.get("base_attributes", template.base_attributes).duplicate()
		else:
			push_error("[BattleSaveModule] 读档失败：找不到对应的敌人 ID " + str(e_id))

	print("[BattleSaveModule] 战斗状态读取完毕，当前处于战斗中: ", is_in_combat)
#endregion

# 供 SaveManager 退回主菜单时清理残留数据
func clear_data() -> void:
	is_in_combat = false
	rng_seed = 0
	input_deck.clear()
	current_deck.clear()
	input_player_data = null
	input_enemy_data = null
	print("[BattleSaveModule] 数据缓存已清理")

#region 战斗快照流程控制【传入参数错误】

# 外部发起战斗时调用
func create_battle_snapshot(save_manager: Node) -> void:
	is_in_combat = true
	rng_seed = randi() # 固定随机数种子，确保重连后战斗随机性不变
	
	# 向全局系统注册并立刻物理保存
	save_manager.register_module(self)
	save_manager.save_game()
	print("[BattleSaveModule] 战前快照生成完毕，游戏已自动保存")

# 战斗正常结束后结算时调用
func resolve_battle(save_manager: Node) -> void:
	is_in_combat = false
	
	save_manager.save_game()
	print("[BattleSaveModule] 战斗结算完毕，战斗标记已清除")

#endregion

#region 向BattleManager提供初始化数据
# 提供一个runtimecard牌组
func process_and_get_runtime_deck() -> Array[RuntimeCard]:
	if not input_deck.is_empty() and current_deck.is_empty():
		_compile_input_to_runtime()
	
	if current_deck.is_empty():
		push_warning("[BattleSaveModule] 警告：没有可用牌组，正在生成测试牌组...")
		build_test_deck()
		
	return current_deck
	print("[BattleSaveModule] 玩家牌组被读取")

# 提供玩家的entitydata
func process_and_get_player_data() -> EntityData:
	if input_player_data: return input_player_data
	return build_test_player_data()
	print("[BattleSaveModule] 玩家数据被读取")

# 提供敌人的enemydata
func process_and_get_enemy_data() -> EnemyData:
	if input_enemy_data:
		return input_enemy_data.duplicate(true) as EnemyData
	
	push_warning("[BattleSaveModule] 警告：未接收到敌人数据，正在生成测试敌人...")
	return build_test_enemy_data()
	print("[BattleSaveModule] 敌人数据被读取")

func _compile_input_to_runtime() -> void:
	current_deck.clear()
	pass

#endregion

#region 测试数据生成器
# 组建测试牌组
func build_test_deck():
	current_deck.clear()
	var card_database = AllCardData.get_cards()
	
	var test_card_ids: Array[int] = [1001, 1001, 1002, 1002] 
	
	for card_id in test_card_ids:
		if card_database.has(card_id):
			var new_card = RuntimeCard.new(card_id, card_database[card_id])
			current_deck.append(new_card)
		else:
			push_error("生成测试牌组警告：找不到 ID 为 %d 的卡牌资源！" % card_id)
# 组建测试玩家数据
func build_test_player_data() -> EntityData:
	return EntityData.new("player_test", {
		"hp": 100.0,
		"stamina": 5.0,
		"max_stamina": 5.0
	})
# 组建测试敌人数据
func build_test_enemy_data() -> EnemyData:
	# 从 AllEnemyData 中拿取对应id 的敌人数据
	var test_enemy = AllEnemyData.get_enemy(1001)
	if test_enemy:
		return test_enemy.duplicate(true)
		
	# 究极兜底方案
	var dummy = EnemyData.new()
	dummy.enemy_id = 999
	dummy.base_attributes = {"hp": 80.0}
	return dummy

#endregion
