extends Node
# save_manager.gd

const SAVE_DIR = "user://saves/"
var current_save: Dictionary = {}

func _ready() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

# 1. 创建全新扁平化存档
func create_new_save(player_name: String) -> String:
	var save_id = str(Time.get_unix_time_from_system())
	
	var default_inventory = [
		{
			"uid": "uid_" + str(Time.get_unix_time_from_system()) + "_1",
			"template_id": "w_001", # 对应图鉴里的锈蚀砍刀
			"location": "equipped_weapon_1", # 出生直接装备在主武器槽
			"current_durability": 100,
			"is_broken": false,
			"equipped_cards": [10001, 10001, 10002] # 玩家精炼后保存的牌组
		},
		{
			"uid": "uid_" + str(Time.get_unix_time_from_system()) + "_2",
			"template_id": "i_001", # 对应治疗药水
			"location": "warehouse", # 出生放在仓库里
			"count": 3
		}
	]
	
	var save_data = {
		"id": save_id,
		"name": player_name,
		"in_raid": false, # 局内死神标记：如果在 true 的状态下读取存档，说明非正常断开或战死
		"inventory": default_inventory 
	}
	
	current_save = save_data
	save_current_state()
	print("💾 存档创建成功！特工: %s, 唯一ID: %s" % [player_name, save_id])
	return save_id

# 2. 方案A：安全双缓冲保存机制 (防崩溃/断电坏档)
func save_current_state() -> void:
	if current_save.is_empty():
		push_error("SaveManager: 当前没有加载存档，无法保存！")
		return
		
	var save_id = current_save["id"]
	var tmp_file_name = "save_" + save_id + ".tmp"
	var json_file_name = "save_" + save_id + ".json"
	
	# 第一步：写入临时文件 .tmp
	var file = FileAccess.open(SAVE_DIR + tmp_file_name, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_save, "\t"))
		file.close()
	else:
		push_error("SaveManager: 临时文件写入失败！")
		return
		
	# 第二步：写入成功后，安全的替换原有 .json 文件
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		# 如果原文件存在，先删掉旧的
		if dir.file_exists(json_file_name):
			var err = dir.remove(json_file_name)
			if err != OK:
				push_error("SaveManager: 无法删除旧存档文件！")
				return
		
		# 将 .tmp 重命名为 .json，完成无缝偷天换日
		var rename_err = dir.rename(tmp_file_name, json_file_name)
		if rename_err == OK:
			print("✅ 游戏进度已安全保存！(双缓冲机制执行完毕)")
		else:
			push_error("SaveManager: 临时文件转正失败！")

# 3. 读取存档与扫描功能 (保持不变，略作优化)
func get_all_saves() -> Array:
	var saves = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var file = FileAccess.open(SAVE_DIR + file_name, FileAccess.READ)
				if file:
					var data = JSON.parse_string(file.get_as_text())
					if typeof(data) == TYPE_DICTIONARY:
						saves.append(data)
			file_name = dir.get_next()
	saves.sort_custom(func(a, b): return a["id"].to_int() > b["id"].to_int())
	return saves

func load_save(save_id: String) -> bool:
	var file_path = SAVE_DIR + "save_" + save_id + ".json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		current_save = JSON.parse_string(file.get_as_text())
		print("📂 成功载入存档！当前特工: ", current_save.get("name", "未知"))
		return true
	push_error("读取失败，找不到文件: ", file_path)
	return false

func delete_save(save_id: String) -> void:
	var dir = DirAccess.open(SAVE_DIR)
	if dir and dir.file_exists("save_" + save_id + ".json"):
		dir.remove("save_" + save_id + ".json")
		print("🗑️ 存档已物理删除。")
