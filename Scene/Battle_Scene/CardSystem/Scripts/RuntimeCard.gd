class_name RuntimeCard
extends RefCounted

signal stats_updated 

var base_card_id: int
var base_data: Dictionary
var active_buffs: Array[CardBuff] = []

# 初始化
func _init(id: int, raw_data: Variant) -> void:
	base_card_id = id
	base_data = {}
	
	if typeof(raw_data) == TYPE_DICTIONARY:
		base_data = raw_data.duplicate(true)
	else:
		for prop in raw_data.get_property_list():
			var prop_name = prop["name"]
			var value = raw_data.get(prop_name)
			if typeof(value) == TYPE_DICTIONARY:
				base_data[prop_name] = value.duplicate(true)
			else:
				base_data[prop_name] = value

func add_buff(buff: CardBuff) -> void:
	active_buffs.append(buff)
	stats_updated.emit()

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

# 辅助方法：向下钻取，遍历 Effects 数组寻找特定的数值
func _get_base_value_from_effects(target_key: String) -> float:
	var effects = base_data.get("effects", [])
	for effect in effects:
		# 判断 effect 是合法的对象实例，且内部存在 target_key 变量
		if effect != null and target_key in effect:
			return float(effect.get(target_key))
	return 0.0

# 获取资源消耗
func get_resource_cost() -> int:
	# 提取 CardType 枚举值 (0 = Attack, 1 = Skill, 2 = Power)
	var type_val = base_data.get("card_type", 0)
	var cost_key = "stamina_cost" if type_val == 0 else "mana_cost"
	# 真正调用钻取方法获取基础值
	var base_res_cost = _get_base_value_from_effects(cost_key)
	return _calculate_property("resource_cost", base_res_cost)

# 获取时间消耗
func get_time_cost() -> int:
	# 真正调用钻取方法获取基础值
	var base_time_cost = _get_base_value_from_effects("time_cost")
	return _calculate_property("time_cost", base_time_cost)

# 编译意图：向 CombatProcessor 输出完整的 effects 资源引用
func compile_effect_data() -> Dictionary:
	var compiled_effect = {}
	var original_effects = base_data.get("effects", [])
	
	# 将特效数组直接暴露给战斗处理器，供其实体结算时使用
	compiled_effect["effects"] = original_effects.duplicate()
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
