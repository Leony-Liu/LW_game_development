extends Node

# Item Database Manager
#
# Main / Shelter / Battle 侧使用的静态物品数据库。
#
# 注意：
# Dungeon 搜索系统当前使用的是它自己的
# ItemDataBase / MAPInventoryManager，
# 这里不负责 Dungeon 的搜索物品逻辑。


const ITEM_DATA_DIRECTORY: String = "res://DataBase/Item/"

const DATA_FILES: Array[String] = [
	"Weapons.csv"
]

const INT_ARRAY_FIELDS: Array[String] = [
	"default_cards",
	"card_pool"
]


var database: Dictionary = {}


func _ready() -> void:
	reload_database()


# Public API

func reload_database() -> void:
	database.clear()

	for file_name in DATA_FILES:
		load_csv_data(
			ITEM_DATA_DIRECTORY + file_name
		)


func get_item_data(
	template_id: String
) -> Dictionary:
	if database.has(template_id):
		return database[template_id]

	return {}


func has_item_data(
	template_id: String
) -> bool:
	return database.has(template_id)


# CSV

func load_csv_data(
	file_path: String
) -> void:
	if not FileAccess.file_exists(file_path):
		push_warning(
			"ItemDatabaseManager: 找不到数据表 -> "
			+ file_path
		)
		return

	var file := FileAccess.open(
		file_path,
		FileAccess.READ
	)

	if file == null:
		push_warning(
			"ItemDatabaseManager: 无法打开数据表 -> "
			+ file_path
		)
		return

	var headers: PackedStringArray = (
		file.get_csv_line()
	)

	if (
		headers.is_empty()
		or headers[0].strip_edges()
		!= "template_id"
	):
		push_warning(
			"ItemDatabaseManager: 数据表不是有效的纯文本 CSV，已跳过 -> "
			+ file_path
		)

		file.close()
		return

	while not file.eof_reached():
		var row: PackedStringArray = (
			file.get_csv_line()
		)

		# 跳过空行。
		if (
			row.size() == 1
			and row[0].strip_edges().is_empty()
		):
			continue

		if row.size() < headers.size():
			push_warning(
				"ItemDatabaseManager: CSV 行字段数量不足，已跳过 -> "
				+ file_path
			)
			continue

		var item_info: Dictionary = {}

		for i in range(headers.size()):
			var key: String = (
				headers[i].strip_edges()
			)

			var raw_value: String = (
				row[i].strip_edges()
			)

			item_info[key] = _parse_value(
				key,
				raw_value
			)

		var template_id: String = str(
			item_info.get(
				"template_id",
				""
			)
		)

		if template_id.is_empty():
			continue

		database[template_id] = item_info

	file.close()

	print(
		"ItemDatabaseManager: 已载入 %s，当前静态物品总数：%d"
		% [
			file_path.get_file(),
			database.size()
		]
	)


func _parse_value(
	key: String,
	value: String
) -> Variant:
	if key in INT_ARRAY_FIELDS:
		var result: Array[int] = []

		if value.is_empty():
			return result

		for part in value.split(";"):
			var clean_part: String = (
				part.strip_edges()
			)

			if clean_part.is_valid_int():
				result.append(
					clean_part.to_int()
				)

		return result

	if value.is_valid_int():
		return value.to_int()

	if value.is_valid_float():
		return value.to_float()

	return value
