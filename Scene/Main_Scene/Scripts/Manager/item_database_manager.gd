extends Node


# ============================================================
# Item Database Manager
# ============================================================
#
# 负责读取全游戏“静态物品定义”。
#
# 当前公共类别：
#
# weapon      武器
# equipment   装备
# usable      道具
# key_item    关键道具
# resource    资源
# supply      物资
#
#
# 设计原则：
#
# 1. 普通物品主要通过 CSV 编辑。
# 2. 新增普通数值字段时，不需要修改本脚本。
# 3. 各类别额外字段统一进入 definition["data"]。
# 4. 保留 get_item_data() 作为旧代码兼容接口。
# 5. 新代码优先使用 get_item_definition()。
#
# ============================================================


const ITEM_DATA_DIRECTORY: String = (
	"res://DataBase/Item/"
)


# ============================================================
# Tables
# ============================================================

## category 不需要重复填写进 CSV。
##
## 表格本身就代表所属类别，
## 可以避免策划填错 category。
const DATA_TABLES: Array[Dictionary] = [
	{
		"file": "Weapons.csv",
		"category": "weapon"
	},
	{
		"file": "Equipment.csv",
		"category": "equipment"
	},
	{
		"file": "Usables.csv",
		"category": "usable"
	},
	{
		"file": "KeyItems.csv",
		"category": "key_item"
	},
	{
		"file": "Resources.csv",
		"category": "resource"
	},
	{
		"file": "Supplies.csv",
		"category": "supply"
	}
]


# ============================================================
# Stable Public Fields
# ============================================================

## 这些字段属于 ItemDefinition 的稳定公共层。
##
## CSV 中其它未知字段全部自动进入：
##
## definition["data"]
##
## 所以后面新增：
##
## base_damage
## attack_speed
## max_uses
## effect_id
##
## 等字段时，不需要回来修改数据库加载器。
const COMMON_FIELDS: Array[String] = [
	"template_id",
	"subtype",
	"name_key",
	"desc_key",
	"icon_path",
	"preview_texture",
	"preview_scene",
	"weight",
	"max_stack",
	"base_value",
	"mechanic_id",
	"dev_note"
]


# ============================================================
# Temporary Legacy Aliases
# ============================================================

## 当前项目旧 Weapons.csv 使用这些名字。
##
## 迁移期间继续支持，
## 这样不用一次性修改 Shelter / Battle。
const FIELD_ALIASES: Dictionary = {
	"desc": "desc_key",
	"wep_type": "subtype"
}


# template_id -> ItemDefinition
var database: Dictionary = {}


func _ready() -> void:
	reload_database()


# ============================================================
# Public API
# ============================================================

func reload_database() -> void:
	database.clear()

	for table_info in DATA_TABLES:
		var file_name: String = str(
			table_info.get(
				"file",
				""
			)
		)

		var category: String = str(
			table_info.get(
				"category",
				""
			)
		)

		if file_name.is_empty():
			continue

		load_csv_data(
			ITEM_DATA_DIRECTORY + file_name,
			category
		)

	print(
		"ItemDatabaseManager: "
		+ "全部静态物品载入完成，共 %d 项。"
		% database.size()
	)


## ------------------------------------------------------------
## 新接口
## ------------------------------------------------------------
##
## 返回结构化 ItemDefinition：
##
## {
##     "template_id": "...",
##     "category": "...",
##     ...
##
##     "data": {
##         类别专属字段
##     }
## }
##
func get_item_definition(
	template_id: String
) -> Dictionary:
	if not database.has(template_id):
		return {}

	var definition: Dictionary = (
		database[template_id]
	)

	return definition.duplicate(
		true
	)


## ------------------------------------------------------------
## 旧接口兼容
## ------------------------------------------------------------
##
## 当前 Shelter 等旧代码仍然会直接访问：
##
## static_data["wep_type"]
## static_data["default_cards"]
## static_data["desc"]
##
## 因此这里把 data 临时摊平。
##
## 新代码不要依赖这个摊平结构。
func get_item_data(
	template_id: String
) -> Dictionary:
	var definition: Dictionary = (
		get_item_definition(
			template_id
		)
	)

	if definition.is_empty():
		return {}

	var result: Dictionary = (
		definition.duplicate(
			true
		)
	)

	var extra_data: Variant = result.get(
		"data",
		{}
	)

	if extra_data is Dictionary:
		for key in extra_data.keys():
			result[key] = extra_data[key]

	# 当前 Shelter UI 的旧字段兼容。
	result["desc"] = str(
		result.get(
			"desc_key",
			""
		)
	)

	result["wep_type"] = str(
		result.get(
			"subtype",
			""
		)
	)

	return result


func has_item_data(
	template_id: String
) -> bool:
	return database.has(
		template_id
	)


func get_all_item_definitions() -> Array:
	var result: Array = []

	for definition in database.values():
		if not definition is Dictionary:
			continue

		result.append(
			definition.duplicate(
				true
			)
		)

	return result


func get_items_by_category(
	category: String
) -> Array:
	var result: Array = []

	for definition in database.values():
		if not definition is Dictionary:
			continue

		if str(
			definition.get(
				"category",
				""
			)
		) != category:
			continue

		result.append(
			definition.duplicate(
				true
			)
		)

	return result


# ============================================================
# CSV
# ============================================================

func load_csv_data(
	file_path: String,
	category: String
) -> void:
	if not FileAccess.file_exists(
		file_path
	):
		push_warning(
			"ItemDatabaseManager: "
			+ "找不到数据表 -> "
			+ file_path
		)

		return

	var file: FileAccess = FileAccess.open(
		file_path,
		FileAccess.READ
	)

	if file == null:
		push_warning(
			"ItemDatabaseManager: "
			+ "无法打开数据表 -> "
			+ file_path
		)

		return

	var headers: PackedStringArray = (
		file.get_csv_line()
	)

	if headers.is_empty():
		push_warning(
			"ItemDatabaseManager: "
			+ "CSV 没有表头 -> "
			+ file_path
		)

		file.close()
		return

	# 处理部分表格软件保存 UTF-8 CSV 时产生的 BOM。
	for i in range(
		headers.size()
	):
		headers[i] = (
			headers[i]
			.replace(
				"\ufeff",
				""
			)
			.strip_edges()
		)

	if not headers.has(
		"template_id"
	):
		push_warning(
			"ItemDatabaseManager: "
			+ "CSV 缺少 template_id 列 -> "
			+ file_path
		)

		file.close()
		return

	var loaded_count: int = 0

	while not file.eof_reached():
		var row: PackedStringArray = (
			file.get_csv_line()
		)

		if _is_empty_row(
			row
		):
			continue

		var raw_row: Dictionary = {}

		for i in range(
			headers.size()
		):
			var key: String = (
				headers[i]
			)

			if key.is_empty():
				continue

			var raw_value: String = ""

			if i < row.size():
				raw_value = (
					row[i]
					.strip_edges()
				)

			raw_row[key] = raw_value

		# enabled 为空时默认启用。
		var enabled_text: String = str(
			raw_row.get(
				"enabled",
				"true"
			)
		).strip_edges().to_lower()

		if enabled_text == "false":
			continue

		var definition: Dictionary = (
			_create_default_definition(
				category
			)
		)

		var extra_data: Dictionary = {}

		for original_key in raw_row.keys():
			var original_key_string: String = str(
				original_key
			)

			if original_key_string == "enabled":
				continue

			var canonical_key: String = (
				_get_canonical_field_name(
					original_key_string
				)
			)

			var raw_value: String = str(
				raw_row[
					original_key
				]
			)

			# 空白公共字段保留默认值。
			#
			# 空白扩展字段则不写入 data，
			# 避免 data 中堆积大量无意义字段。
			if raw_value.is_empty():
				continue

			var parsed_value: Variant = (
				_parse_value(
					raw_value
				)
			)

			if canonical_key in COMMON_FIELDS:
				definition[
					canonical_key
				] = parsed_value
			else:
				extra_data[
					canonical_key
				] = parsed_value

		definition[
			"data"
		] = extra_data

		var template_id: String = str(
			definition.get(
				"template_id",
				""
			)
		).strip_edges()

		if template_id.is_empty():
			push_warning(
				"ItemDatabaseManager: "
				+ "%s 中发现没有 template_id 的行，已跳过。"
				% file_path.get_file()
			)

			continue

		if database.has(
			template_id
		):
			push_error(
				"ItemDatabaseManager: "
				+ "发现重复 template_id -> "
				+ template_id
				+ "，来源："
				+ file_path
			)

			continue

		database[
			template_id
		] = definition

		loaded_count += 1

	file.close()

	print(
		"ItemDatabaseManager: "
		+ "已载入 %s：%d 项。"
		% [
			file_path.get_file(),
			loaded_count
		]
	)


# ============================================================
# Definition
# ============================================================

func _create_default_definition(
	category: String
) -> Dictionary:
	return {
		"template_id": "",
		"category": category,
		"subtype": "",
		"name_key": "",
		"desc_key": "",
		"icon_path": "",
		"preview_texture": "",
		"preview_scene": "",
		"weight": 0.0,
		"max_stack": 1,
		"base_value": 0,
		"mechanic_id": "",
		"dev_note": "",
		"data": {}
	}


func _get_canonical_field_name(
	field_name: String
) -> String:
	if FIELD_ALIASES.has(
		field_name
	):
		return str(
			FIELD_ALIASES[
				field_name
			]
		)

	return field_name


# ============================================================
# Parsing
# ============================================================

## V1 CSV 值规则：
##
## true / false
##     -> bool
##
## 10
##     -> int
##
## 1.5
##     -> float
##
## [1;2;3]
##     -> Array[int]
##
## [dungeon;battle]
##     -> Array[String]
##
## 其它内容
##     -> String
##
## 使用 [] 明确表示数组，
## 避免把普通字符串中的 ; 错误拆分。
func _parse_value(
	value: String
) -> Variant:
	var clean_value: String = (
		value.strip_edges()
	)

	if clean_value.is_empty():
		return ""

	var lower_value: String = (
		clean_value.to_lower()
	)

	if lower_value == "true":
		return true

	if lower_value == "false":
		return false

	if (
		clean_value.begins_with(
			"["
		)
		and clean_value.ends_with(
			"]"
		)
	):
		return _parse_array(
			clean_value
		)

	return _parse_scalar(
		clean_value
	)


func _parse_array(
	value: String
) -> Array:
	var result: Array = []

	var content: String = (
		value.substr(
			1,
			value.length() - 2
		)
		.strip_edges()
	)

	if content.is_empty():
		return result

	for part in content.split(
		";"
	):
		var clean_part: String = (
			part.strip_edges()
		)

		if clean_part.is_empty():
			continue

		result.append(
			_parse_scalar(
				clean_part
			)
		)

	return result


func _parse_scalar(
	value: String
) -> Variant:
	var lower_value: String = (
		value.to_lower()
	)

	if lower_value == "true":
		return true

	if lower_value == "false":
		return false

	if value.is_valid_int():
		return value.to_int()

	if value.is_valid_float():
		return value.to_float()

	return value


func _is_empty_row(
	row: PackedStringArray
) -> bool:
	if row.is_empty():
		return true

	for value in row:
		if not value.strip_edges().is_empty():
			return false

	return true
