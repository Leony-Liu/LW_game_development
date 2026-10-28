## 管理存档槽和模块 JSON I/O，不持有玩法状态。
## 写入使用临时文件提交，关键操作向调用者返回成功结果。
extends Node

const SAVE_DIR = "user://saves/"

# 保存输入的存档模块
var _modules: Dictionary = {}
var _retained_module_data: Dictionary = {}

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
func register_module(module: SaveModule) -> bool:
	var key = module.get_module_key()
	if _modules.has(key):
		if _modules[key] == module:
			return true
		push_error("[SaveManager] 模块注册失败：键名 %s 已被其他模块使用。" % key)
		return false
	_modules[key] = module
	print("[SaveManager] 成功注册存档模块: ", key)
	return true

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
func create_new_save(slot_id: String, save_name: String, save_immediately: bool = true) -> bool:
	if not _is_slot_id_valid(slot_id) or FileAccess.file_exists(SAVE_DIR + slot_id + ".json"):
		push_error("[SaveManager] 创建失败：槽位无效或已存在，拒绝覆盖。")
		return false
	current_slot_id = slot_id
	current_metadata = {
		"save_name": save_name,
		"creation_time": Time.get_datetime_string_from_system()
	}
	# 让所有模块清空数据，以纯净状态开始
	_clear_all_modules()
	_retained_module_data.clear()
	print("[SaveManager] 创建并锁定了新存档槽位: ", slot_id)
	# 创建后立即保存一次，生成物理文件
	return save_game() if save_immediately else true

# 加载某个存档
func load_slot(slot_id: String) -> bool:
	load_started.emit()
	if not _is_slot_id_valid(slot_id):
		return _load_failed("存档槽位 ID 无效。")
	var target_path = SAVE_DIR + slot_id + ".json"
	if not FileAccess.file_exists(target_path):
		return _load_failed("找不到目标存档文件：%s。" % target_path)
	var file = FileAccess.open(target_path, FileAccess.READ)
	if file == null:
		return _load_failed("无法打开存档：%s。" % target_path)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	if error != OK or not json.data is Dictionary:
		return _load_failed("JSON 损坏或根数据不是字典。")
	var root_dict: Dictionary = json.data
	if not root_dict.get("metadata") is Dictionary or not root_dict.get("modules_data") is Dictionary:
		return _load_failed("缺少有效 metadata 或 modules_data。")
	var modules_data: Dictionary = root_dict["modules_data"]
	for key in _modules:
		if not modules_data.has(key):
			return _load_failed("缺少必需模块 %s；保留原文件与当前状态。" % key)
	var previous: Dictionary = {}
	for key in _modules:
		previous[key] = _modules[key].get_save_data()
	for key in _modules:
		if not _modules[key].try_load_save_data(modules_data[key]):
			for rollback_key in previous:
				if not _modules[rollback_key].try_load_save_data(previous[rollback_key]):
					push_error("[SaveManager] 模块 %s 内存回滚失败。" % rollback_key)
			return _load_failed("模块 %s 恢复失败；未提交槽位切换。" % key)
	current_slot_id = slot_id
	current_metadata = root_dict["metadata"].duplicate(true)
	_retained_module_data = modules_data.duplicate(true)
	load_finished.emit(true)
	print("[SaveManager] 读取完成：%s。" % slot_id)
	return true

# 保存一次所有存档模块的数据
func save_game() -> bool:
	save_started.emit()
	if not _is_slot_id_valid(current_slot_id):
		return _save_failed("未锁定有效存档槽位。")
	# 保留同一存档中尚未注册的模块，不覆盖其原数据。
	var modules_data := _retained_module_data.duplicate(true)
	for key in _modules:
		if not _modules[key].can_save():
			return _save_failed("模块 %s 拒绝保存无效状态。" % key)
		modules_data[key] = _modules[key].get_save_data()
	var metadata := current_metadata.duplicate(true)
	metadata["last_played"] = Time.get_datetime_string_from_system()
	var root_dict = {
		"metadata": metadata,
		"modules_data": modules_data
	}
	
	var target_path = SAVE_DIR + current_slot_id + ".json"
	var temporary_path = target_path + ".tmp"
	var file = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _save_failed("无法创建临时文件：%s。" % temporary_path)
	file.store_string(JSON.stringify(root_dict, "  "))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return _save_failed("临时文件写入失败：%s。" % error_string(write_error))
	var commit_error := DirAccess.rename_absolute(temporary_path, target_path)
	if commit_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return _save_failed("文件提交失败：%s；原存档保留。" % error_string(commit_error))
	current_metadata = metadata
	_retained_module_data = modules_data
	save_finished.emit(true)
	print("[SaveManager] 保存完成：%s。" % target_path)
	return true


# 限制为当前 saves 目录内的单一文件名。
func _is_slot_id_valid(slot_id: String) -> bool:
	return not slot_id.is_empty() and slot_id.is_valid_filename() and slot_id not in [".", ".."]


# 所有保存失败都向调用方与监听者返回相同结果。
func _save_failed(reason: String) -> bool:
	push_error("[SaveManager] 保存失败：%s" % reason)
	save_finished.emit(false)
	return false


# 读取失败不改变当前槽位，也不改写原文件。
func _load_failed(reason: String) -> bool:
	push_error("[SaveManager] 读取失败：%s" % reason)
	load_finished.emit(false)
	return false

# 玩家退出当前游戏，返回主菜单时调用
func unload_current_save():
	print("[SaveManager] 正在卸载当前存档，重置状态...")
	current_slot_id = ""
	current_metadata.clear()
	_retained_module_data.clear()
	_clear_all_modules()
	print("[SaveManager] 已退回无存档锁定状态。")

# 内部辅助函数：命令所有注册的模块清理自身内存
func _clear_all_modules():
	for key in _modules:
		_modules[key].clear_data()
