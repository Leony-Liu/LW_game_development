## 保存玩家拥有的武器及当前武器身份、远征恢复标记。
## 只序列化长期数据，旧容器迁移保留原卡牌身份和顺序。
class_name PlayerCardSaveModule
extends SaveModule

const WeaponInstance = preload("res://Scripts/RefCounted/WeaponInstance.gd")
var owned_weapons: Array[WeaponInstance] = []
var current_weapon_uid: String = ""
var expedition_was_active: bool = false
var _card_database: Dictionary
var _weapon_database: Dictionary

# 静态模板由外部注入，存档模块不选择新游戏武器。
func _init(cards: Dictionary, weapons: Dictionary = {}) -> void:
	_card_database = cards
	_weapon_database = weapons

# 保留原模块键，允许旧槽位无损迁移。
func get_module_key() -> String:
	return "player_cards"

# 当前原型只使用一把武器，模型允许保存多把。
func get_current_weapon() -> WeaponInstance:
	for weapon in owned_weapons:
		if weapon.unique_id == current_weapon_uid:
			return weapon
	return null

# 输出武器实例，不保存地图、敌人或 RuntimeCard。
func get_save_data() -> Dictionary:
	var weapons: Array[Dictionary] = []
	for weapon in owned_weapons:
		weapons.append(weapon.to_dictionary())
	return {"schema_version": 2, "owned_weapons": weapons, "current_weapon_uid": current_weapon_uid, "expedition_was_active": expedition_was_active}

# 同时检查武器身份、容器归属、容量和跨武器卡牌 UID。
func can_save() -> bool:
	if (owned_weapons.is_empty() and not current_weapon_uid.is_empty()) or (not owned_weapons.is_empty() and get_current_weapon() == null):
		return _fail("当前武器身份无效。")
	var seen_weapons: Dictionary = {}
	var seen_cards: Dictionary = {}
	for weapon in owned_weapons:
		if weapon == null or weapon.weapon_id <= 0 or weapon.unique_id.is_empty() or seen_weapons.has(weapon.unique_id):
			return _fail("武器身份无效或重复。")
		seen_weapons[weapon.unique_id] = true
		if weapon.weapon_data != null and weapon.weapon_data.id != weapon.weapon_id:
			return _fail("武器模板引用不匹配。")
		if weapon.combat_deck == null or weapon.reserve_deck == null or weapon.combat_deck == weapon.reserve_deck:
			return _fail("武器缺少两个独立容器。")
		if weapon.combat_deck.container_id != "combat_deck" or weapon.reserve_deck.container_id != "reserve_deck" or weapon.combat_deck.capacity != 20 or weapon.combat_deck.get_cards().size() > 20:
			return _fail("容器身份或战斗牌组容量无效。")
		for container in [weapon.combat_deck, weapon.reserve_deck]:
			for card in container.get_cards():
				if card.card_id <= 0 or card.unique_id.is_empty() or seen_cards.has(card.unique_id):
					return _fail("卡牌身份无效或跨容器重复。")
				if card.container_ref == null or card.container_ref.get_ref() != container:
					return _fail("卡牌所属容器不一致。")
				if card.card_data != null and card.card_data.id != card.card_id:
					return _fail("卡牌模板引用不匹配。")
				seen_cards[card.unique_id] = true
	return true

# 保留 SaveModule 原接口，调用者应使用带结果的恢复入口。
func load_save_data(data: Variant) -> void:
	try_load_save_data(data)

# 在临时模型内完整恢复，失败不改变当前状态。
func try_load_save_data(data: Variant) -> bool:
	if not data is Dictionary or not data.get("expedition_was_active") is bool:
		return _fail("恢复数据或远征标记无效。")
	var restored: PlayerCardSaveModule = load("res://Scripts/RefCounted/PlayerCardSaveModule.gd").new(_card_database, _weapon_database)
	restored.expedition_was_active = data["expedition_was_active"]
	if not data.has("schema_version"):
		if not restored._migrate_legacy(data):
			return false
	elif data.get("schema_version") == 2 and data.get("owned_weapons") is Array and data.get("current_weapon_uid") is String:
		restored.current_weapon_uid = data["current_weapon_uid"]
		for entry in data["owned_weapons"]:
			var weapon := WeaponInstance.from_dictionary(entry, _card_database, _weapon_database)
			if weapon == null:
				return _fail("武器实例恢复失败；保留原存档。")
			restored.owned_weapons.append(weapon)
	else:
		return _fail("不支持的存档版本或无效武器数组。")
	if not restored.can_save():
		return false
	owned_weapons = restored.owned_weapons
	current_weapon_uid = restored.current_weapon_uid
	expedition_was_active = restored.expedition_was_active
	return true

# 旧 weapon_deck 转为战斗牌组，warehouse 转为同一武器的备用牌组。
func _migrate_legacy(data: Dictionary) -> bool:
	if not data.get("player_initialized") is bool or not data.get("containers") is Array:
		return _fail("旧存档结构无效，拒绝覆盖。")
	var raw_id: Variant = data.get("weapon_id")
	if not (raw_id is int or raw_id is float) or int(raw_id) != raw_id:
		return _fail("旧 weapon_id 无效。")
	var old: Dictionary = {}
	for entry in data["containers"]:
		var container := CardContainer.from_dictionary(entry, _card_database)
		if container == null or old.has(container.container_id) or container.container_id not in ["weapon_deck", "warehouse"]:
			return _fail("旧容器存在重复、未知身份或损坏条目，拒绝推定归属。")
		old[container.container_id] = container
	if not old.has("weapon_deck") or not old.has("warehouse"):
		return _fail("旧存档缺少必需容器。")
	if not data["player_initialized"]:
		if int(raw_id) != 0 or not old.weapon_deck.get_cards().is_empty() or not old.warehouse.get_cards().is_empty():
			return _fail("旧存档存在无武器归属的卡牌；需用户决定归属，原文件保留。")
		return true
	if int(raw_id) <= 0:
		return _fail("旧存档已初始化但武器 ID 无效。")
	var weapon := WeaponInstance.new(int(raw_id), _weapon_database.get(int(raw_id)))
	var overflow := 0
	for card in old.weapon_deck.get_cards():
		var target := weapon.combat_deck if weapon.combat_deck.get_cards().size() < 20 else weapon.reserve_deck
		if target == weapon.reserve_deck:
			overflow += 1
		if not old.weapon_deck.transfer_to(target, card.unique_id):
			return false
	for card in old.warehouse.get_cards():
		if not old.warehouse.transfer_to(weapon.reserve_deck, card.unique_id):
			return false
	owned_weapons.append(weapon)
	current_weapon_uid = weapon.unique_id
	push_warning("[PlayerCardSaveModule] 旧 weapon_deck 已迁入战斗牌组，warehouse 迁入武器备用牌组；超限 %d 张先于仓库卡追加到备用牌组。原卡牌 UID、修改器及各来源顺序保留。" % overflow)
	return true

# 卸载不创建新武器或卡牌。
func clear_data() -> void:
	owned_weapons.clear()
	current_weapon_uid = ""
	expedition_was_active = false

# 结构错误明确拒绝恢复或保存。
func _fail(reason: String) -> bool:
	push_error("[PlayerCardSaveModule] %s" % reason)
	return false
