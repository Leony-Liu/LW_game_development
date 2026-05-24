# 定义：效果管理器(单例)
# 作用：
# A.解析数据库传出来的字符串并分发任务
# B.具体的效果函数
# 备注：
# 效果方法名 = "_effect_" + 在CSV表格里面写的效果名称


extends Node


# A.核心入口：解析字符串并分发任务
func execute_effects(effect_string: String, source_node: Node, target_node: Node):
	if effect_string == "" or effect_string == "0": return
	var effect_list = effect_string.split(";")
	
	for effect_item in effect_list:
		var parts = effect_item.split(":")
		var effect_name = parts[0].strip_edges()
		
		var method_name = "_effect_" + effect_name
		if has_method(method_name):
			# 核心修改：将拆分后的字符串数组 (parts) 整体传给方法，让方法自己决定如何提取
			call(method_name, parts, source_node, target_node)
		else:
			push_error("效果管理器：未找到效果方法 -> " + method_name)

# ==========================================
# 具体效果实现
# ==========================================
# ==========================================
# 具体效果实现
# ==========================================

# 1. 易伤效果 (适配了新的 parts 数组参数)
func _effect_vulnerable(parts: PackedStringArray, source: Node, target: Node):
	# parts = ["vulnerable", "数值"]
	var val1 = parts[1].to_float() if parts.size() > 1 else 1.0
	
	if target.has_node("Data/CombatData"):
		target.get_node("Data/CombatData").vulnerable_stacks += int(val1)
		print("⚔️ 施加易伤！剩余次数: ", target.get_node("Data/CombatData").vulnerable_stacks)

# 2. 万能状态挂载器 (取代了之前的 charge 和 attack_surge)
func _effect_add_buff(parts: PackedStringArray, source: Node, target: Node):
	# CSV 格式要求： add_buff:buff的英文名:数值:持续时间
	# 举例 蓄力： add_buff:charge:10:999 (999代表无限时间，直到攻击被消耗)
	# 举例 增幅： add_buff:attack_surge:0.5:10
	if parts.size() < 4: 
		push_error("⚠️ add_buff 效果参数不足！正确格式应为 add_buff:buff_id:数值:时间")
		return
		
	var buff_id = parts[1].strip_edges()
	var value = parts[2].to_float()
	var duration = parts[3].to_float()
	
	# 注意：如果你写的是给玩家自己的 buff，在卡牌打出时 source 通常就是玩家
	# 但由于目前你有些增益是写在技能牌上的，技能牌的 target 其实也是自己
	# 为了保险起见，增益 buff 通常直接挂在打出者 (source) 身上
	if source.has_node("Data/CombatData"):
		source.get_node("Data/CombatData").apply_buff(buff_id, value, duration)
