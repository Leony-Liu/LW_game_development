# effect_manager.gd
# A.解析数据库传出来的字符串并分发任务
# B.具体的效果函数

extends Node

func execute_effects(effect_string: String, source_node: Node, target_node: Node):
	if effect_string == "" or effect_string == "0": return
	var effect_list = effect_string.split(";")
	
	for effect_item in effect_list:
		var parts = effect_item.split(":")
		var effect_name = parts[0].strip_edges()
		
		var method_name = "_effect_" + effect_name
		if has_method(method_name):
			call(method_name, parts, source_node, target_node)
		else:
			push_error("效果管理器：未找到效果方法 -> " + method_name)

# ==========================================
# 具体效果实现
# ==========================================

# 1. 易伤效果 
func _effect_vulnerable(parts: PackedStringArray, source: Node, target: Node):
	var val1 = parts[1].to_float() if parts.size() > 1 else 1.0
	if target.has_node("Data/CombatData"):
		target.get_node("Data/CombatData").vulnerable_stacks += int(val1)

# 2. 万能状态挂载器 (解决：下次攻击、限时状态增益)
func _effect_add_buff(parts: PackedStringArray, source: Node, target: Node):
	# 正确格式： add_buff:buff_id:数值:时间
	# 压步配置示例： add_buff:next_atk_mult:0.5:999 
	# 蓄力配置示例： add_buff:damage_up_percent:0.25:5
	if parts.size() < 4: 
		push_error("⚠️ add_buff 效果参数不足！正确格式应为 add_buff:buff_id:数值:时间")
		return
		
	var buff_id = parts[1].strip_edges()
	var value = parts[2].to_float()
	var duration = parts[3].to_float()
	
	if source.has_node("Data/CombatData"):
		source.get_node("Data/CombatData").apply_buff(buff_id, value, duration)

# 3. 【新增】：手牌动态强化器 (解决：振奋攻击)
func _effect_buff_hand(parts: PackedStringArray, source: Node, target: Node):
	# 格式规范： buff_hand:目标大类:修改属性:增加数值
	# 振奋攻击示例： buff_hand:attack:damage:10
	if parts.size() < 4:
		push_error("⚠️ buff_hand 参数不足！格式应为 buff_hand:category:stat_name:value")
		return
		
	var target_category = parts[1].strip_edges()
	var stat_name = parts[2].strip_edges()
	var value = parts[3].to_float()
	
	# 通过相对路径找到同级的 CardManager
	var card_manager = get_node_or_null("../CardManager")
	if card_manager and card_manager.has_method("apply_buff_to_hand"):
		card_manager.apply_buff_to_hand(target_category, stat_name, value)
	else:
		push_error("效果管理器：未找到 CardManager 或缺失对应强化方法！")
