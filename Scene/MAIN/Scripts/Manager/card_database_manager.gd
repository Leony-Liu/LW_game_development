#定义：卡牌数据库读取工具（单例）

# 作用：
# A.读取存储所有卡牌数据的csv文件，并制作成一个个字典
# B.提供了一个方法可供全局调用


extends Node

# 用于存放所有卡牌数据的字典。键(Key)是卡牌ID，值(Value)是卡牌具体信息的字典
var database : Dictionary = {}

func _ready():
	load_csv_data("res://DataBase/AllCardData.csv")#调用方法并传入csv数据库地址

# A.加载csv数据库的数据并打包
func load_csv_data(file_path: String):
	# 1. 打开文件
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	# 查错反馈
	if not file:
		push_error("数据库读取：找不到卡牌数据文件: " + file_path)
		return

	# --- 关键修改：读取第一行直接作为表头 (Headers) ---
	# 之前这里有两行读取，现在只需要一行
	var headers = file.get_csv_line()
	
	# 2. 循环读取剩下的每一行数据
	while not file.eof_reached():
		var data_row = file.get_csv_line()
		
		# 如果是空行则跳过 (或者列数少于表头也跳过)
		if data_row.size() < headers.size():
			continue
			
		var card_info = {}
		
		# 将数据与表头对应起来
		for i in range(headers.size()):
			# 容错：防止行数据列数不够
			if i < data_row.size():
				var header_name = headers[i]
				var cell_value = data_row[i]
				
				# --- 防止空数据 ---
				# 1. 拦截空字符串，默认为整数 0
				if cell_value == "":
					card_info[header_name] = 0
				# 2. 正常的纯数字字符串，转换为整数
				elif cell_value.is_valid_int():
					card_info[header_name] = cell_value.to_int()
				 # 3. 其他的（比如纯文字或字母组合），保留为字符串
				else:
					card_info[header_name] = cell_value
					
					
				# CSV 读进来的全部是字符串 (String)
				# 逻辑：如果是纯数字字符串，自动转换回整数 (int)
				if cell_value.is_valid_int():
					card_info[header_name] = cell_value.to_int()
				else:
					card_info[header_name] = cell_value
		
		# 3. 使用卡牌的 "id" 作为主键存入 database 字典
		if card_info.has("id"):
			var card_id = card_info["id"]
			database[card_id] = card_info
		
	print("数据库读取：卡牌数据库加载完成，共加载了 %d 张卡牌。" % database.size())

# B.提供一个读取卡牌的方式
func get_card(id: int) -> Dictionary:
	if database.has(id):
		return database[id]
	else:
		push_error("数据库读取：找不到ID为 %d 的卡牌!" % id)
		return {}
