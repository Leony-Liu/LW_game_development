extends Node

const SAVE_DIR = "user://saves/"

# 保存输入的存档模块
var _modules: Dictionary = {}

# 当前读取的存档文件
var current_slot_id: String = "" 
# 存放当前存档的所有数据
var current_metadata: Dictionary = {} 

# 进程信号
signal save_started
signal save_finished(success: bool)
signal load_started
signal load_finished(success: bool)

# 引擎启动时，确保本地存在 saves 文件夹
func _ready():
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)
	print("[SaveManager] 存档系统就绪。等待业务模块注册...")

# 供外部系统输入存档模块
func register_module(module: SaveModule):
	var key = module.get_module_key()
	if _modules.has(key):
		push_warning("[SaveManager] 模块键名重复注册，将被覆盖: ", key)
	_modules[key] = module
	print("[SaveManager] 成功注册存档模块: ", key)

# 供主菜单 UI 使用：扫描文件夹，返回所有存档信息（目前为存档名称）
func get_save_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var slot_id = file_name.replace(".json", "")
				var file = FileAccess.open(SAVE_DIR + file_name, FileAccess.READ)
				if file:
					var json_string = file.get_as_text()
					var json = JSON.new()
					if json.parse(json_string) == OK and json.data.has("metadata"):
						# 仅提取元数据，附加 slot_id 以便 UI 知道这是哪个文件
						var summary = json.data["metadata"]
						summary["slot_id"] = slot_id
						summaries.append(summary)
					file.close()
			file_name = dir.get_next()
		dir.list_dir_end()
	return summaries

# 删除指定的存档文件
func delete_save(slot_id: String):
	var path = SAVE_DIR + slot_id + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[SaveManager] 已删除存档文件: ", slot_id)

# 创建新的存档文件
func create_new_save(slot_id: String, save_name: String):
	current_slot_id = slot_id
	current_metadata = {
		"save_name": save_name,
		"creation_time": Time.get_datetime_string_from_system()
	}
	# 让所有模块清空数据，以纯净状态开始
	_clear_all_modules()
	print("[SaveManager] 创建并锁定了新存档槽位: ", slot_id)
	# 创建后立即保存一次，生成物理文件
	save_game()

# 加载某个存档
func load_slot(slot_id: String):
	var target_path = SAVE_DIR + slot_id + ".json"
	if not FileAccess.file_exists(target_path):
		push_error("[SaveManager] 找不到目标存档文件: ", target_path)
		return
		
	emit_signal("load_started")
	current_slot_id = slot_id # 锁定槽位
	print("[SaveManager] 锁定存档槽位，开始读取: ", slot_id)
	
	var file = FileAccess.open(target_path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error == OK:
		var root_dict = json.data
		
		# 1. 恢复元数据
		if root_dict.has("metadata"):
			current_metadata = root_dict["metadata"]
			
		# 2. 恢复模块具体数据
		if root_dict.has("modules_data"):
			var modules_data = root_dict["modules_data"]
			for key in _modules:
				if modules_data.has(key):
					_modules[key].load_save_data(modules_data[key])
				else:
					push_warning("[SaveManager] 存档中缺少已注册模块的数据: ", key)
					
		emit_signal("load_finished", true)
		print("[SaveManager] 游戏读取成功！")
	else:
		current_slot_id = "" # 读取失败，解除锁定
		emit_signal("load_finished", false)
		push_error("[SaveManager] 存档文件损坏或解析失败！")

# 保存一次所有存档模块的数据
func save_game():
	if current_slot_id == "":
		push_error("[SaveManager] 未锁定任何存档槽位，拒绝保存！")
		return
		
	emit_signal("save_started")
	
	# 更新元数据
	current_metadata["last_played"] = Time.get_datetime_string_from_system()
	
	# 收集所有模块的数据
	var modules_data = {}
	for key in _modules:
		modules_data[key] = _modules[key].get_save_data()
		
	# 组装最终写入 JSON 的根字典
	var root_dict = {
		"metadata": current_metadata,
		"modules_data": modules_data
	}
	
	var target_path = SAVE_DIR + current_slot_id + ".json"
	var file = FileAccess.open(target_path, FileAccess.WRITE)
	if file:
		# 以两空格缩进格式化输出，纯文本方便查看调试
		file.store_string(JSON.stringify(root_dict, "  "))
		file.close()
		emit_signal("save_finished", true)
		print("[SaveManager] 游戏保存成功！已写入: ", target_path)
	else:
		emit_signal("save_finished", false)
		push_error("[SaveManager] 写入存档文件失败！")

# 玩家退出当前游戏，返回主菜单时调用
func unload_current_save():
	print("[SaveManager] 正在卸载当前存档，重置状态...")
	current_slot_id = ""
	current_metadata.clear()
	_clear_all_modules()
	print("[SaveManager] 已退回无存档锁定状态。")

# 内部辅助函数：命令所有注册的模块清理自身内存
func _clear_all_modules():
	for key in _modules:
		_modules[key].clear_data()
