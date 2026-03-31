# 定义：效果管理器(单例)
# 作用：
# A.解析数据库传出来的字符串并分发任务
# B.具体的效果函数
# 备注：
# 效果方法名 = "_effect_" + 在CSV表格里面写的效果名称


extends Node


# A.核心入口：解析字符串并分发任务
func execute_effects(effect_string: String, source_node: Node, target_node: Node):
	if effect_string == "" or effect_string == "0":
		return
	
	# 1. 如果有多个效果（比如 "vulnerable:20;draw:1"），先用分号拆分
	var effect_list = effect_string.split(";")
	
	for effect_item in effect_list:
		# 2. 拆分名字和数值（比如 "vulnerable:20" -> ["vulnerable", "20"]）
		var parts = effect_item.split(":")
		var effect_name = parts[0].strip_edges() # 去掉多余空格
		
		# 提取数值，如果没有数值（比如只有 "parry"），默认为 0 或 1
		var value = 0.0
		if parts.size() > 1:
			value = parts[1].to_float()
		
		# 3. 根据名字寻找对应的方法执行
		# 利用 Godot 的 call 方法，动态调用本脚本中的函数
		var method_name = "_effect_" + effect_name
		if has_method(method_name):
			call(method_name, value, source_node, target_node)# 通过“字符串名字”来强制执行对应函数
		else:
			print("效果管理器：警告：未定义的效果方法 -> ", method_name)

# --- ！！ B.以下是具体的效果函数，名字必须和 CSV 里的对应上，加上前缀 _effect_ ！！ ---

func _effect_vulnerable(value: float, source, target):
	print("效果管理器：对目标施加 %.1f%% 易伤" % value)



func _effect_attack_power(value: float, source, target):
	print("效果管理器：玩家攻击力提升: ", value)



func _effect_player_hp(value: float, source, target):
	print("效果管理器：玩家回复生命值: ", value)
