## 加载并索引用户编写的静态 WeaponData，校验卡牌模板引用。
## 空库有效；不创建武器实例或玩家牌组状态。
extends Node

const WEAPONS_DIR: String = "res://Scripts/WeaponData/Weapons/"

var initialization_succeeded: bool = false
var _weapon_database: Dictionary[int, WeaponData] = {}


# AllCardData 先初始化，再建立武器索引并保存明确结果。
func _ready() -> void:
	initialization_succeeded = _load_all_weapons()


# 扫描同层资源，全部有效后才发布索引；无资源时正常成功。
func _load_all_weapons() -> bool:
	_weapon_database.clear()
	var directory := DirAccess.open(WEAPONS_DIR)
	if directory == null:
		push_error("[AllWeaponData] 初始化失败：无法打开武器目录 %s。" % WEAPONS_DIR)
		return false

	var pending: Dictionary[int, WeaponData] = {}
	var seen_ids: Dictionary[int, String] = {}
	var card_database: Dictionary = AllCardData.get_cards()
	var file_names := directory.get_files()
	file_names.sort()
	var is_valid := true
	for file_name in file_names:
		if not file_name.ends_with(".tres"):
			continue
		var file_path := WEAPONS_DIR.path_join(file_name)
		var weapon := ResourceLoader.load(file_path) as WeaponData
		if weapon == null:
			push_error("[AllWeaponData] 初始化失败：%s 无法加载为 WeaponData。" % file_path)
			is_valid = false
			continue
		if weapon.id <= 0:
			push_error("[AllWeaponData] 初始化失败：%s 的武器 ID 必须为正整数。" % file_path)
			is_valid = false
			continue
		if seen_ids.has(weapon.id):
			push_error("[AllWeaponData] 初始化失败：武器 ID %d 重复，资源为 %s 和 %s。" % [weapon.id, seen_ids[weapon.id], file_path])
			is_valid = false
			continue
		seen_ids[weapon.id] = file_path
		if not _validate_starting_deck(weapon, card_database, file_path):
			is_valid = false
			continue
		pending[weapon.id] = weapon

	# 拒绝发布部分有效的库，调用方可检查 initialization_succeeded。
	if not is_valid:
		return false
	_weapon_database = pending
	print("[AllWeaponData] 初始化完成，共加载 %d 个武器定义。" % _weapon_database.size())
	return true


# 限制起始战斗容量；缺失可选卡牌只诊断，创建实例时跳过。
func _validate_starting_deck(weapon: WeaponData, card_database: Dictionary, file_path: String) -> bool:
	var is_valid := true
	if weapon.starting_combat_deck_card_ids.size() > 20:
		push_error("[AllWeaponData] 初始战斗牌组超过 20 张：%s。" % file_path)
		return false
	for card_id in weapon.starting_combat_deck_card_ids + weapon.starting_reserve_deck_card_ids:
		if not card_database.get(card_id) is CardData:
			push_warning("[AllWeaponData] %s 缺少 CardData ID %d；创建新武器时跳过该引用。" % [file_path, card_id])
	return is_valid


# 返回索引副本，模板本身仍是共享的静态资源。
func get_weapons() -> Dictionary[int, WeaponData]:
	return _weapon_database.duplicate()


# 未登记的 ID 返回 null，空库查询不触发重新加载或报错。
func get_weapon(id: int) -> WeaponData:
	return _weapon_database.get(id) as WeaponData
