# 全游戏存档管理
# 负责读取各系统提交的SaveModule
extends Node

# 将原本的单一文件路径，改为一个专属的存档文件夹
const SAVE_DIR = "user://saves/"

# 模块注册表，存放所有 SaveModule 的实例
var _modules: Dictionary = {}

var deck_module: DeckSaveModule 


var current_slot_id: String = "default_slot"

func _ready():
	# 引擎启动时，确保本地存在 saves 文件夹
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)
		
	_initialize_modules()
	
	
	print("[SaveManager] 多存档系统初始化完成，当前槽位：", current_slot_id)

# 初始化并注册所有的存档模块 
func _initialize_modules():
	deck_module = DeckSaveModule.new() 
	_register_module(deck_module) 

# 将模块加入字典 
func _register_module(module: SaveModule):
	_modules[module.get_module_key()] = module 

#region 多存档管理
# 动态获取当前槽位对应的本地文件路径
func _get_current_save_path() -> String:
	return SAVE_DIR + current_slot_id + ".json"

# 切换当前的存档槽位（由 UI 系统在主菜单调用）
func set_current_slot(slot_id: String):
	current_slot_id = slot_id
	print("[SaveManager] 已切换至存档槽位：", current_slot_id)

# 获取目前所有存在的存档槽位名称（供主菜单生成“读档列表”使用）
func get_all_save_slots() -> Array[String]:
	var slots: Array[String] = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				# 去掉 ".json" 后缀，暴露出纯净的 slot_id
				slots.append(file_name.replace(".json", ""))
			file_name = dir.get_next()
		dir.list_dir_end()
	return slots

# 删除指定存档
func delete_save(slot_id: String):
	var path = SAVE_DIR + slot_id + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[SaveManager] 删除了存档：", slot_id)
#endregion


#region 读写数据
func save_game():
	var save_dict = {}
	
	for key in _modules: 
		var module = _modules[key] 
		save_dict[key] = module.get_save_data() 
		
	# 使用动态路径代替写死的常量
	var target_path = _get_current_save_path()
	var file = FileAccess.open(target_path, FileAccess.WRITE) 
	if file: 
		file.store_string(JSON.stringify(save_dict, "  ")) 
		file.close() 
		print("[SaveManager] 游戏保存成功！保存在：", target_path)
	else: 
		push_error("[SaveManager] 存档写入失败！") 

func load_game():
	var target_path = _get_current_save_path()
	
	if not FileAccess.file_exists(target_path):
		print("[SaveManager] 未找到存档文件，属于全新游戏。") 
		# 如果是新游戏，我们可能需要清空当前内存中的旧数据（比如上一个存档留下的牌组）
		# 为防止串档，这里提供一个安全清空机制：
		_clear_all_modules_data()
		return 
		
	var file = FileAccess.open(target_path, FileAccess.READ) 
	var json_string = file.get_as_text() 
	file.close() 
	
	var json = JSON.new() 
	var error = json.parse(json_string) 
	
	if error == OK: 
		var save_dict = json.data 
		for key in save_dict: 
			if _modules.has(key): 
				_modules[key].load_save_data(save_dict[key]) 
			else: 
				push_warning("[SaveManager] 存档中存在未知的模块数据键名: ", key) 
		print("[SaveManager] 游戏读取成功！读取自：", target_path)
	else: 
		push_error("[SaveManager] 存档文件损坏或解析失败！") 

# 内部辅助函数：用于读取空存档时，重置所有系统的数据
func _clear_all_modules_data():
	# 你可以在这里让所有模块执行一个 clear 方法，目前为了简单，我直接清空 deck
	deck_module.current_deck.clear()
#endregion
