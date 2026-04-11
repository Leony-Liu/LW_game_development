# MechanicDatabaseManager (自动加载单例)
#
# 加载数据库
# 提供一个机制抽取方法

extends Node

var database: Dictionary = {}

func _ready():
	load_csv_data("res://DataBase/EnemyMechanicsData.csv")

# ==========================================
# 数据库加载
# ==========================================
func load_csv_data(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("找不到机制数据库文件: " + file_path)
		return

	var headers = file.get_csv_line()
	
	while not file.eof_reached():
		var data_row = file.get_csv_line()
		if data_row.size() < headers.size():
			continue
			
		var mech_info = {}
		for i in range(headers.size()):
			if i < data_row.size():
				var header_name = headers[i]
				var cell_value = data_row[i]
				
				if cell_value.is_valid_int():
					mech_info[header_name] = cell_value.to_int()
				else:
					mech_info[header_name] = cell_value
		
		if mech_info.has("id"):
			database[mech_info["id"]] = mech_info
			
	print("机制数据库加载完成，共 %d 个机制。" % database.size())

# ==========================================
# 机制抽取算法
# ==========================================
# 抽取算法（输入：敌人等级、机制数量）
func roll_mechanics_for_tier(enemy_tier: int, count: int) -> Array[String]:
	var valid_mechanics: Array[String] = []
	var selected_mechanics: Array[String] = []
	
	# 1. 筛选出所有符合当前怪物阶级 (Tier) 的机制
	for mech_id in database:
		var mech_data = database[mech_id]
		# 规则：怪物的 Tier 必须 >= 机制的 Tier 才能用这个机制
		# 比如 Boss (Tier 4) 可以抽 Tier 1~4 的所有机制，但小怪 (Tier 1) 只能抽 Tier 1
		if mech_data.has("tier") and mech_data["tier"] <= enemy_tier:
			valid_mechanics.append(mech_data["mechanic_name"])
			
	# 2. 如果池子是空的，直接返回
	if valid_mechanics.is_empty():
		return selected_mechanics
		
	# 3. 随机抽取指定数量的机制（不重复抽取）
	valid_mechanics.shuffle() # 打乱池子
	
	for i in range(min(count, valid_mechanics.size())):
		selected_mechanics.append(valid_mechanics[i])
		
	return selected_mechanics
