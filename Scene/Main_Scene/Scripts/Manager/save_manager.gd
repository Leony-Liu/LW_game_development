extends Node


# ============================================================
# Save Manager
# ============================================================
#
# 一个 save_xxx.json = 一个完整游戏进度。
#
# 当前包含：
#
# - 基础存档信息
# - Inventory
# - Raid 状态
# - Shelter
#
# 未来：
# - Quest
# - Character Progression
# - Map Progress
# - Settings bound to save
# ...
#
#
# save_meta.cfg 不是游戏存档。
# 它只记录：
#
# last_save_id
#
# 用于主菜单“开始游戏”快速进入上一次存档。
# ============================================================


const SAVE_DIR: String = "user://saves/"
const META_PATH: String = "user://save_meta.cfg"

const SAVE_VERSION: int = 3
const INVENTORY_SAVE_VERSION: int = 1
const SHELTER_SAVE_VERSION: int = 1

var current_save: Dictionary = {}

var _meta: ConfigFile = ConfigFile.new()


func _ready() -> void:
	_ensure_save_directory()
	_load_meta()


# ============================================================
# Public - Create
# ============================================================


func create_new_save(
	player_name: String
) -> String:
	var clean_name: String = (
		player_name.strip_edges()
	)

	if clean_name.is_empty():
		push_warning(
			"SaveManager: 存档名称不能为空。"
		)
		return ""

	var save_id: String = _generate_save_id()

	var now: int = int(
		Time.get_unix_time_from_system()
	)

	var default_inventory: Array = [
		{
			"uid": "uid_%s_1" % save_id,
			"template_id": "w_001",
			"location": "equipped_weapon_1",
			"count": 1,

			"state": {
				"current_durability": 100,
				"is_broken": false,

				"equipped_cards": [
					10001,
					10001,
					10002
				]
			}
		},
		{
			"uid": "uid_%s_2" % save_id,
			"template_id": "i_001",
			"location": "warehouse",
			"count": 3,

			"state": {}
		}
	]

	current_save = {
		"save_version": SAVE_VERSION,

		"id": save_id,
		"name": clean_name,

		"created_at_unix": now,
		"last_played_at_unix": now,

		"in_raid": false,

		"inventory_version": INVENTORY_SAVE_VERSION,
		"inventory": default_inventory,

		"shelter": _create_default_shelter_data()
	}

	if not save_current_state():
		current_save.clear()
		return ""

	_set_last_save_id(
		save_id
	)

	print(
		"SaveManager: 创建存档 %s (%s)"
		% [
			clean_name,
			save_id
		]
	)

	return save_id


# ============================================================
# Public - Save
# ============================================================


func save_current_state() -> bool:
	if current_save.is_empty():
		push_warning(
			"SaveManager: 当前没有加载存档，跳过保存。"
		)
		return false

	current_save = _normalize_save_data(
		current_save
	)

	current_save["save_version"] = SAVE_VERSION

	current_save["last_played_at_unix"] = int(
		Time.get_unix_time_from_system()
	)

	var save_id: String = str(
		current_save.get(
			"id",
			""
		)
	)

	if save_id.is_empty():
		push_error(
			"SaveManager: current_save 缺少 id。"
		)
		return false

	var tmp_name: String = (
		"save_%s.tmp" % save_id
	)

	var json_name: String = (
		"save_%s.json" % save_id
	)

	var tmp_path: String = (
		SAVE_DIR + tmp_name
	)

	var file: FileAccess = FileAccess.open(
		tmp_path,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"SaveManager: 无法创建临时存档文件。"
		)
		return false

	file.store_string(
		JSON.stringify(
			current_save,
			"\t"
		)
	)

	file.close()

	var dir: DirAccess = DirAccess.open(
		SAVE_DIR
	)

	if dir == null:
		push_error(
			"SaveManager: 无法打开存档目录。"
		)
		return false

	if dir.file_exists(
		json_name
	):
		var remove_error: Error = dir.remove(
			json_name
		)

		if remove_error != OK:
			push_error(
				"SaveManager: 无法删除旧存档。"
			)
			return false

	var rename_error: Error = dir.rename(
		tmp_name,
		json_name
	)

	if rename_error != OK:
		push_error(
			"SaveManager: 临时存档转正失败。"
		)
		return false

	return true


# ============================================================
# Public - Load
# ============================================================


func load_save(
	save_id: String
) -> bool:
	var data: Dictionary = _read_save_file(
		save_id
	)

	if data.is_empty():
		push_error(
			"SaveManager: 无法读取存档 %s"
			% save_id
		)
		return false

	current_save = _normalize_save_data(
		data
	)

	current_save["last_played_at_unix"] = int(
		Time.get_unix_time_from_system()
	)

	_set_last_save_id(
		save_id
	)

	# 同时完成旧版本存档迁移。
	save_current_state()

	print(
		"SaveManager: 已载入 %s"
		% current_save.get(
			"name",
			"Unknown"
		)
	)

	return true


# ============================================================
# Public - List
# ============================================================


func get_all_saves() -> Array:
	var result: Array = []

	var dir: DirAccess = DirAccess.open(
		SAVE_DIR
	)

	if dir == null:
		return result

	dir.list_dir_begin()

	var file_name: String = dir.get_next()

	while not file_name.is_empty():
		if (
			not dir.current_is_dir()
			and file_name.begins_with("save_")
			and file_name.ends_with(".json")
		):
			var file: FileAccess = FileAccess.open(
				SAVE_DIR + file_name,
				FileAccess.READ
			)

			if file != null:
				var parsed: Variant = JSON.parse_string(
					file.get_as_text()
				)

				file.close()

				if typeof(parsed) == TYPE_DICTIONARY:
					var data: Dictionary = parsed

					result.append(
						_normalize_save_data(
							data
						)
					)

		file_name = dir.get_next()

	dir.list_dir_end()

	result.sort_custom(
		_sort_saves_newest_first
	)

	return result


func has_any_save() -> bool:
	return not get_all_saves().is_empty()


# ============================================================
# Public - Last Save
# ============================================================


func get_last_save_id() -> String:
	var saved_id: String = str(
		_meta.get_value(
			"General",
			"last_save_id",
			""
		)
	)

	if (
		not saved_id.is_empty()
		and FileAccess.file_exists(
			_get_save_path(saved_id)
		)
	):
		return saved_id

	# 上一次存档被删除 / meta 不存在：
	# 自动选择最近游玩的存档。
	var saves: Array = get_all_saves()

	if saves.is_empty():
		_set_last_save_id("")
		return ""

	var first_save: Dictionary = saves[0]

	var fallback_id: String = str(
		first_save.get(
			"id",
			""
		)
	)

	_set_last_save_id(
		fallback_id
	)

	return fallback_id


# ============================================================
# Public - Delete
# ============================================================


func delete_save(
	save_id: String
) -> bool:
	if save_id.is_empty():
		return false

	var dir: DirAccess = DirAccess.open(
		SAVE_DIR
	)

	if dir == null:
		return false

	var json_name: String = (
		"save_%s.json" % save_id
	)

	var tmp_name: String = (
		"save_%s.tmp" % save_id
	)

	if dir.file_exists(
		json_name
	):
		var error: Error = dir.remove(
			json_name
		)

		if error != OK:
			push_error(
				"SaveManager: 删除存档失败。"
			)
			return false

	if dir.file_exists(
		tmp_name
	):
		dir.remove(
			tmp_name
		)

	if (
		not current_save.is_empty()
		and str(
			current_save.get(
				"id",
				""
			)
		) == save_id
	):
		current_save.clear()

	var last_id: String = str(
		_meta.get_value(
			"General",
			"last_save_id",
			""
		)
	)

	if last_id == save_id:
		_set_last_save_id("")
		get_last_save_id()

	print(
		"SaveManager: 已删除存档 %s"
		% save_id
	)

	return true


# ============================================================
# Public - Shelter
# ============================================================


func get_shelter_data() -> Dictionary:
	if current_save.is_empty():
		return _create_default_shelter_data()

	var shelter_value: Variant = current_save.get(
		"shelter",
		_create_default_shelter_data()
	)

	if typeof(shelter_value) != TYPE_DICTIONARY:
		return _create_default_shelter_data()

	var result: Dictionary = shelter_value

	return result.duplicate(
		true
	)


func set_shelter_data(
	data: Dictionary,
	save_immediately: bool = true
) -> void:
	if current_save.is_empty():
		push_warning(
			"SaveManager: 没有加载存档，无法写入 Shelter 数据。"
		)
		return

	current_save["shelter"] = data.duplicate(
		true
	)

	if save_immediately:
		save_current_state()


# ============================================================
# Internal - Read
# ============================================================


func _read_save_file(
	save_id: String
) -> Dictionary:
	var path: String = _get_save_path(
		save_id
	)

	if not FileAccess.file_exists(
		path
	):
		return {}

	var file: FileAccess = FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)

	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	var result: Dictionary = parsed

	return result


# ============================================================
# Internal - Migration / Defaults
# ============================================================


func _normalize_save_data(
	data: Dictionary
) -> Dictionary:
	var result: Dictionary = data.duplicate(
		true
	)

	var save_id: String = str(
		result.get(
			"id",
			""
		)
	)

	var inferred_time: int = _infer_time_from_id(
		save_id
	)

	if not result.has(
		"save_version"
	):
		result["save_version"] = SAVE_VERSION

	if not result.has(
		"name"
	):
		result["name"] = "Unnamed Save"

	if not result.has(
		"created_at_unix"
	):
		result["created_at_unix"] = inferred_time

	if not result.has(
		"last_played_at_unix"
	):
		result["last_played_at_unix"] = int(
			result.get(
				"created_at_unix",
				inferred_time
			)
		)

	if not result.has(
		"in_raid"
	):
		result["in_raid"] = false

	# ========================================================
	# Inventory Migration
	# ========================================================

	var raw_inventory: Variant = result.get(
		"inventory",
		[]
	)

	result["inventory"] = (
		_normalize_inventory_data(
			raw_inventory,
			save_id
		)
	)

	result[
		"inventory_version"
	] = INVENTORY_SAVE_VERSION

	# ========================================================
	# Shelter
	# ========================================================

	if (
		not result.has("shelter")
		or typeof(
			result["shelter"]
		) != TYPE_DICTIONARY
	):
		result["shelter"] = (
			_create_default_shelter_data()
		)

	return result


func _normalize_inventory_data(
	raw_inventory: Variant,
	save_id: String
) -> Array:
	var result: Array = []

	if not raw_inventory is Array:
		push_warning(
			"SaveManager: "
			+ "inventory 不是 Array，已重置为空库存。"
		)

		return result

	var inventory: Array = raw_inventory

	for index in range(
		inventory.size()
	):
		var value: Variant = inventory[index]

		if not value is Dictionary:
			push_warning(
				"SaveManager: "
				+ "库存第 %d 项不是 Dictionary，已跳过。"
				% index
			)

			continue

		var source: Dictionary = (
			value as Dictionary
		)

		# ----------------------------------------------------
		# UID
		# ----------------------------------------------------

		var uid: String = str(
			source.get(
				"uid",
				""
			)
		).strip_edges()

		# 非常旧的测试数据如果没有 UID，
		# 自动生成一个稳定的迁移 UID。
		if uid.is_empty():
			uid = (
				"uid_%s_legacy_%d"
				% [
					save_id,
					index
				]
			)

		# ----------------------------------------------------
		# Template
		# ----------------------------------------------------

		var template_id: String = str(
			source.get(
				"template_id",
				""
			)
		).strip_edges()

		if template_id.is_empty():
			push_warning(
				"SaveManager: "
				+ "库存物品 %s 缺少 template_id。"
				% uid
			)

		# ----------------------------------------------------
		# Location
		# ----------------------------------------------------

		var location: String = str(
			source.get(
				"location",
				"warehouse"
			)
		).strip_edges()

		if location.is_empty():
			location = "warehouse"

		# ----------------------------------------------------
		# Count
		# ----------------------------------------------------

		var count: int = int(
			source.get(
				"count",
				1
			)
		)

		if count <= 0:
			count = 1

		# ----------------------------------------------------
		# State
		# ----------------------------------------------------

		var state: Dictionary = {}

		var existing_state: Variant = source.get(
			"state",
			{}
		)

		if existing_state is Dictionary:
			state = (
				existing_state as Dictionary
			).duplicate(
				true
			)

		# 旧版本物品实例把动态字段直接放在顶层。
		#
		# V1 中除了这五个公共字段以外，
		# 其它实例字段全部自动迁移进入 state。
		#
		# 这样 current_durability /
		# is_broken /
		# equipped_cards 等现有数据不会丢失，
		# 将来其它未知旧字段也能保留下来。
		for key in source.keys():
			var field_name: String = str(
				key
			)

			if field_name in [
				"uid",
				"template_id",
				"location",
				"count",
				"state"
			]:
				continue

			# 如果新的 state 已经拥有同名字段，
			# 优先保留 state 中的数据。
			if state.has(
				field_name
			):
				continue

			state[
				field_name
			] = source[
				key
			]

		var normalized_item: Dictionary = {
			"uid": uid,
			"template_id": template_id,
			"location": location,
			"count": count,
			"state": state
		}

		result.append(
			normalized_item
		)

	return result


func _create_default_shelter_data() -> Dictionary:
	return {
		"version": SHELTER_SAVE_VERSION,

		# 每一个 Room 内部还会包含它自己的设施。
		"rooms": [],

		# 删除房间后暂时进入 Shelter Storage 的设施。
		"facility_storage": []
	}


# ============================================================
# Internal - Meta
# ============================================================


func _load_meta() -> void:
	var error: Error = _meta.load(
		META_PATH
	)

	if (
		error != OK
		and error != ERR_FILE_NOT_FOUND
	):
		push_warning(
			"SaveManager: save_meta.cfg 读取失败。"
		)


func _set_last_save_id(
	save_id: String
) -> void:
	_meta.set_value(
		"General",
		"last_save_id",
		save_id
	)

	var error: Error = _meta.save(
		META_PATH
	)

	if error != OK:
		push_warning(
			"SaveManager: 无法保存 last_save_id。"
		)


# ============================================================
# Internal - Utility
# ============================================================


func _ensure_save_directory() -> void:
	var dir: DirAccess = DirAccess.open(
		"user://"
	)

	if dir == null:
		push_error(
			"SaveManager: 无法打开 user://"
		)
		return

	if not dir.dir_exists(
		"saves"
	):
		var error: Error = dir.make_dir(
			"saves"
		)

		if error != OK:
			push_error(
				"SaveManager: 无法创建 saves 文件夹。"
			)


func _generate_save_id() -> String:
	var unix: int = int(
		Time.get_unix_time_from_system()
	)

	var suffix: int = (
		Time.get_ticks_msec()
		% 1000000
	)

	return "%d_%06d" % [
		unix,
		suffix
	]


func _get_save_path(
	save_id: String
) -> String:
	return (
		SAVE_DIR
		+ "save_"
		+ save_id
		+ ".json"
	)


func _infer_time_from_id(
	save_id: String
) -> int:
	if save_id.is_empty():
		return 0

	var first_part: String = (
		save_id.get_slice(
			"_",
			0
		)
	)

	return first_part.to_int()


func _sort_saves_newest_first(
	a: Dictionary,
	b: Dictionary
) -> bool:
	var a_time: int = int(
		a.get(
			"last_played_at_unix",
			0
		)
	)

	var b_time: int = int(
		b.get(
			"last_played_at_unix",
			0
		)
	)

	return a_time > b_time
