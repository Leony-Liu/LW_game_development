class_name SaveModule
extends RefCounted

# 返回该模块在 JSON 字典中的 Key（例如："player_deck", "base_building"）
func get_module_key() -> String:
	push_error("SaveModule: 必须重写 get_module_key() 方法！")
	return "default_key"

# 统筹该模块要保存的数据，返回一个字典或数组
func get_save_data():
	push_error("SaveModule: 必须重写 get_save_data() 方法！")
	return {}

# 接收从硬盘读取出来的数据，并恢复系统状态
func load_save_data(_data):
	push_error("SaveModule: 必须重写 load_save_data() 方法！")

# 当玩家退回主菜单（卸载存档）时，SaveManager 会统一调用此方法清空本模块在内存中的数据，防止前一个存档的数据残留。
func clear_data():
	push_error("SaveModule: 必须重写 clear_data() 方法！")
