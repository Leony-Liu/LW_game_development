extends Node

const SAVE_DIR = "user://saves/"
var current_save: Dictionary = {}


func _ready() -> void:
	# 游戏启动时，检查并创建存档专属文件夹
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

# 极简版：仅保存名字
func create_new_save(player_name: String) -> String:
	var save_id = str(Time.get_unix_time_from_system()) 
	
	var save_data = {
		"id": save_id,
		"name": player_name
	}
	
	var file_path = SAVE_DIR + "save_" + save_id + ".json"
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		print("存档创建成功！玩家姓名: %s, 路径: %s" % [player_name, file_path])
		return save_id # 【新增】返回创建的 ID
	else:
		push_error("存档创建失败！")
		return "" # 【新增】失败则返回空字符串


# ==========================================
# 扫描并获取所有本地存档
# ==========================================
func get_all_saves() -> Array:
	var saves = []
	var dir = DirAccess.open(SAVE_DIR)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		# 遍历文件夹里的所有文件
		while file_name != "":
			# 只要是 .json 结尾的文件就尝试读取
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var file = FileAccess.open(SAVE_DIR + file_name, FileAccess.READ)
				if file:
					var content = file.get_as_text()
					var data = JSON.parse_string(content)
					# 确保读取出来的是字典格式
					if typeof(data) == TYPE_DICTIONARY:
						saves.append(data)
			file_name = dir.get_next()
			
	# 根据时间戳(id)对存档进行倒序排列，最新建的存档排在最前面
	saves.sort_custom(func(a, b): return a["id"].to_int() > b["id"].to_int())
	return saves

# ==========================================
# 读取选中的存档进入内存
# ==========================================
func load_save(save_id: String) -> bool:
	var file_path = SAVE_DIR + "save_" + save_id + ".json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file:
		var content = file.get_as_text()
		current_save = JSON.parse_string(content)
		print("💾 成功读取存档！当前特工: ", current_save.get("name", "未知"))
		return true
	else:
		push_error("读取存档失败，找不到文件: ", file_path)
		return false


# ==========================================
# 删除指定存档
# ==========================================
func delete_save(save_id: String) -> void:
	var file_name = "save_" + save_id + ".json"
	var dir = DirAccess.open(SAVE_DIR)
	
	if dir and dir.file_exists(file_name):
		var err = dir.remove(file_name)
		if err == OK:
			print("🗑️ 存档已物理删除: ", file_name)
		else:
			push_error("删除失败，错误码: ", err)
	else:
		push_error("找不到要删除的存档文件！")
