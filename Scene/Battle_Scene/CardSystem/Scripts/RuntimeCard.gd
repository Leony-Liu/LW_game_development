# 战斗内的卡牌实体数据载体。
class_name RuntimeCard
extends RefCounted

# 数据更新信号
signal stats_updated 

var base_card_id: int
var base_data: Dictionary
var active_buffs: Array[CardBuff] = []

# 实例化卡牌
func _init(id: int, data: Dictionary) -> void:
	base_card_id = id
	base_data = data.duplicate(true) 

# 添加信号
func add_buff(buff: CardBuff) -> void:
	active_buffs.append(buff)
	stats_updated.emit()

# 计时删除buff
func advance_time(delta: int) -> void:
	var needs_update = false
	for i in range(active_buffs.size() - 1, -1, -1):
		if active_buffs[i].tick_time(delta):
			active_buffs.remove_at(i)
			needs_update = true
	if needs_update:
		stats_updated.emit()

# 计数删除buff
func consume_action_event() -> void:
	var needs_update = false
	for i in range(active_buffs.size() - 1, -1, -1):
		if active_buffs[i].tick_count():
			active_buffs.remove_at(i)
			needs_update = true
	if needs_update:
		stats_updated.emit()

# 获取当前资源消耗（体力/法力）：用于 UI 显示与出牌校验
func get_resource_cost() -> int:
	var is_attack = str(base_data.get("categories", "attack")) == "attack"
	var base_res_cost = float(base_data.get("stamina_cost" if is_attack else "mana_cost", 0))
	return _calculate_property("resource_cost", base_res_cost)

# 获取当前时间消耗（时间轴排期延迟）：用于加入 Timeline 时计算 trigger_time
func get_time_cost() -> int:
	var base_time_cost = float(base_data.get("cost", 0))
	return _calculate_property("time_cost", base_time_cost)

# 编译战斗意图，交由通用计算管道处理
func compile_effect_data() -> Dictionary:
	var compiled_effect = base_data.get("effect_data", {}).duplicate(true)
	
	# 如果效果中包含伤害，计算最终伤害值
	if compiled_effect.has("damage"):
		compiled_effect["damage"] = _calculate_property("damage", float(compiled_effect["damage"]))
		
	# 如果有其他需要修饰的数值，也可以在此处按同逻辑添加
	# if compiled_effect.has("heal"):
	#     compiled_effect["heal"] = _calculate_property("heal", float(compiled_effect["heal"]))
		
	return compiled_effect

# 内部核心计算管线
func _calculate_property(prop_name: String, base_value: float) -> int:
	var relevant_buffs: Array[CardBuff] = []
	for buff in active_buffs:
		if buff.target_property == prop_name:
			relevant_buffs.append(buff)
			
	if relevant_buffs.is_empty():
		return maxi(0, int(round(base_value)))
		
	# 按照 CardBuff.ModifierType 的枚举整数值升序排序 (SET=0, ADD=1, MULTIPLY=2)
	relevant_buffs.sort_custom(func(a, b): return a.mod_type < b.mod_type)
	
	var final_value = base_value
	for buff in relevant_buffs:
		final_value = buff.apply_modifier(final_value)
		
	# 四舍五入后转为整型，并做下限 0 的钳制保护
	return maxi(0, int(round(final_value)))
