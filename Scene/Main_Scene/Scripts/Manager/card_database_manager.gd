# 读取卡牌数据并打包
extends Node

const CARD_DATABASE_PATH := "res://DataBase/AllCardData.csv"

# 这些字段读取后应该是整数
const INT_FIELDS := [
	"id",
	"time_cost",
	"action_speed",
	"stamina_cost",
	"mana_cost",
	"damage",
	"poise_damage"
]

# 键：卡牌ID
# 值：卡牌基础模板
var database: Dictionary = {}


# 节点就绪时自动触发CSV数据的读取
func _ready() -> void:
	load_csv_data(CARD_DATABASE_PATH)


#region 将csv打包成一个字典
# 读取指定路径的CSV文件并解析为字典存入数据库
func load_csv_data(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		push_error("card_database_manager：找不到卡牌数据文件：" + file_path)
		return

	# 防止重复加载时保留旧数据
	database.clear()

	var headers := file.get_csv_line()

	# 清理表头两侧可能存在的空格
	for i in range(headers.size()):
		headers[i] = headers[i].strip_edges()

	while not file.eof_reached():
		var data_row := file.get_csv_line()

		# 跳过空行
		if data_row.size() == 1 and data_row[0].strip_edges() == "":
			continue

		if data_row.size() < headers.size():
			push_warning("card_database_manager：某一行的列数不足，已跳过：%s" % str(data_row))
			continue

		var card_info: Dictionary = {}

		for i in range(headers.size()):
			var header_name: String = headers[i]
			var cell_value: String = data_row[i].strip_edges()
			card_info[header_name] = _parse_cell(header_name, cell_value)

		if not card_info.has("id"):
			push_warning("card_database_manager：发现没有ID的卡牌数据。")
			continue

		var card_id: int = card_info["id"]

		if database.has(card_id):
			push_warning("card_database_manager：发现重复的卡牌ID：%d" % card_id)
			continue

		database[card_id] = card_info

	print("card_database_manager：卡牌数据库加载完成，共加载了%d张卡牌。" % database.size())


# 根据字段名称将CSV中的字符串值转换为对应的数据类型
func _parse_cell(header_name: String, cell_value: String) -> Variant:
	if header_name in INT_FIELDS:
		if cell_value == "":
			return 0

		if not cell_value.is_valid_int():
			push_warning("card_database_manager：字段%s应当是整数，但读取到：%s" % [header_name, cell_value])
			return 0

		return cell_value.to_int()

	# 字符串字段为空时保持为空字符串
	return cell_value
#endregion


# 根据卡牌ID查询数据库并返回该卡牌数据的独立字典副本
func get_card(id: int) -> Dictionary:
	if database.has(id):
		return database[id].duplicate(true)

	push_error("card_database_manager：找不到ID为%d的卡牌！" % id)
	return {}
