extends Node
# item_database_manager.gd

var database: Dictionary = {}

func _ready() -> void:
	# 启动时自动加载所有的物品表 (你需要先在项目中建好这些文件)
	load_csv_data("res://DataBase/Items/Weapons.csv")
	load_csv_data("res://DataBase/Items/Armors.csv")
	load_csv_data("res://DataBase/Items/Materials.csv")

func load_csv_data(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		push_warning("ItemDatabaseManager: 暂未找到文件，请稍后配置 -> " + file_path)
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var headers = file.get_csv_line()
	
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < headers.size(): continue
		
		var item_info = {}
		for i in range(headers.size()): 
			var key = headers[i]
			var val = row[i]
			
			# 核心解析：针对包含多个卡牌ID的特殊列，用分号切割成数组
			if key in ["default_cards", "card_pool"] and val != "":
				var str_array = val.split(";")
				var int_array = []
				for s in str_array: int_array.append(s.to_int())
				item_info[key] = int_array
			elif val.is_valid_int():
				item_info[key] = val.to_int()
			elif val.is_valid_float():
				item_info[key] = val.to_float()
			else:
				item_info[key] = val
				
		if item_info.has("template_id") and item_info["template_id"] != "":
			database[item_info["template_id"]] = item_info

	print("图鉴数据库: 成功载入 %s，当前总条目数: %d" % [file_path.get_file(), database.size()])

# 全局获取物品基础静态数据的方法
func get_item_data(template_id: String) -> Dictionary:
	if database.has(template_id):
		return database[template_id]
	push_error("ItemDatabaseManager: 图鉴中查无此物 -> ", template_id)
	return {}
