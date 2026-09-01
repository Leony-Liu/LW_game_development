class_name RuntimeCard
extends RefCounted

signal stats_updated 

var card_id: int
var card_data: Dictionary
var active_buffs: Array[CardBuff] = []

# 初始化
func _init(id: int, raw_data: Variant) -> void:
	card_id = id
	card_data = {}
	
	if typeof(raw_data) == TYPE_DICTIONARY:
		card_data = raw_data.duplicate(true)
	elif raw_data != null and raw_data.has_method("get_property_list"):
		for prop in raw_data.get_property_list():
			var prop_name = prop["name"]
			var value = raw_data.get(prop_name)
			if typeof(value) == TYPE_DICTIONARY:
				card_data[prop_name] = value.duplicate(true)
			else:
				card_data[prop_name] = value

# 打包存数据方法（供 SaveModule 持久化保存使用）
func to_dictionary() -> Dictionary:
	return {
		"card_id": card_id,
		"card_data": card_data
	}

# 从字典快速反序列化生成实例的静态方法
static func from_dictionary(dict: Dictionary) -> RuntimeCard:
	var c_id = dict.get("card_id", 0)
	var c_data = dict.get("card_data", {})
	if c_id == 0:
		return null
	return RuntimeCard.new(c_id, c_data)

# 添加单个buff
func add_buff(buff: CardBuff) -> void:
	active_buffs.append(buff)
	stats_updated.emit()

# 经过了多少时间
func advance_time(delta: int) -> void:
	var needs_update = false
	for i in range(active_buffs.size() - 1, -1, -1):
		if active_buffs[i].tick_time(delta):
			active_buffs.remove_at(i)
			needs_update = true
	if needs_update:
		stats_updated.emit()

func consume_action_event() -> void:
	var needs_update = false
	for i in range(active_buffs.size() - 1, -1, -1):
		if active_buffs[i].tick_count():
			active_buffs.remove_at(i)
			needs_update = true
	if needs_update:
		stats_updated.emit()

# 获取资源消耗
func get_resource_cost() -> int:
	var type_val = card_data.get("card_type", 0)
	var cost_key = "stamina_cost" if type_val == 0 else "mana_cost"
	var base_res_cost = float(card_data.get(cost_key, 0.0))
	return _calculate_property("resource_cost", base_res_cost)

# 获取时间消耗
func get_time_cost() -> int:
	var base_time_cost = float(card_data.get("time_cost", 0.0))
	return _calculate_property("time_cost", base_time_cost)

# 获取行动名称
func get_action_name() -> String:
	return card_data.get("name", "Unknown Action")

# 获取优先级
func get_priority() -> int:
	var base_priority = float(card_data.get("priority", 1.0))
	return _calculate_property("priority", base_priority)

# 编译意图：向 ProcessorManager 输出完整的效果与数值
func compile_effect_data() -> Dictionary:
	var compiled_effect = {}
	var original_effects = card_data.get("effects", [])
	
	compiled_effect["effects"] = original_effects.duplicate()
	# 将直观数据打包给战斗处理器（包含经过 Buff 修正后的数值）
	var base_damage = float(card_data.get("damage", 0))
	compiled_effect["damage"] = _calculate_property("damage", base_damage)
	return compiled_effect

# 内部管线结算
func _calculate_property(prop_name: String, base_value: float) -> int:
	var relevant_buffs: Array[CardBuff] = []
	for buff in active_buffs:
		if buff.target_property == prop_name:
			relevant_buffs.append(buff)
			
	if relevant_buffs.is_empty():
		return maxi(0, int(round(base_value)))
		
	relevant_buffs.sort_custom(func(a, b): return a.mod_type < b.mod_type)
	
	var final_value = base_value
	for buff in relevant_buffs:
		final_value = buff.apply_modifier(final_value)
		
	return maxi(0, int(round(final_value)))
