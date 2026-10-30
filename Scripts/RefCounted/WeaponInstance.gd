## 持有具体武器的稳定身份、模板及两个独立牌组。
## 只管理长期数据，不访问全局数据库或战斗状态。
class_name WeaponInstance
extends RefCounted

const COMBAT_LIMIT: int = 20
var unique_id: String
var weapon_id: int
var weapon_data: WeaponData
var combat_deck: CardContainer
var reserve_deck: CardContainer

# 新实例生成身份，恢复实例沿用已保存身份。
func _init(id: int, template: WeaponData, uid: String = "") -> void:
	weapon_id = id
	weapon_data = template
	unique_id = Crypto.new().generate_random_bytes(32).hex_encode() if uid.is_empty() else uid
	combat_deck = CardContainer.new("combat_deck", COMBAT_LIMIT)
	reserve_deck = CardContainer.new("reserve_deck")

# 保留武器与卡牌身份，显式复制双容器及全部可变实例数据。
func clone() -> WeaponInstance:
	if weapon_id <= 0 or unique_id.strip_edges().is_empty() or (weapon_data != null and weapon_data.id != weapon_id):
		push_error("[WeaponInstance] 复制失败：武器身份或模板无效。")
		return null
	if combat_deck == null or reserve_deck == null or combat_deck == reserve_deck:
		push_error("[WeaponInstance] 复制失败：缺少两个独立牌组容器。")
		return null
	var combat_copy := combat_deck.clone()
	var reserve_copy := reserve_deck.clone()
	if combat_copy == null or reserve_copy == null:
		return null
	var seen: Dictionary = {}
	for container in [combat_copy, reserve_copy]:
		for card in container.get_cards():
			if seen.has(card.unique_id):
				push_error("[WeaponInstance] 复制失败：双牌组存在重复卡牌 UID。")
				return null
			seen[card.unique_id] = true
	var copied: WeaponInstance = load("res://Scripts/RefCounted/WeaponInstance.gd").new(weapon_id, weapon_data, unique_id)
	copied.combat_deck = combat_copy
	copied.reserve_deck = reserve_copy
	return copied

# 每个模板引用创建独立实例；缺失的可选卡牌只跳过并诊断。
static func create_starting(template: WeaponData, cards: Dictionary) -> WeaponInstance:
	if template == null or template.starting_combat_deck_card_ids.size() > COMBAT_LIMIT:
		push_error("[WeaponInstance] 创建失败：武器模板无效或战斗牌组超过 20 张。")
		return null
	var weapon: WeaponInstance = load("res://Scripts/RefCounted/WeaponInstance.gd").new(template.id, template)
	var groups := [template.starting_combat_deck_card_ids, template.starting_reserve_deck_card_ids]
	var containers := [weapon.combat_deck, weapon.reserve_deck]
	for i in range(groups.size()):
		for card_id in groups[i]:
			var card := cards.get(card_id) as CardData
			if card == null:
				push_warning("[WeaponInstance] 初始引用缺少 CardData ID %d；跳过该项。" % card_id)
				continue
			if not containers[i].add_card(CardInstance.new(card_id, card)):
				return null
	return weapon

# 仅序列化模板 ID、身份及有序容器。
func to_dictionary() -> Dictionary:
	return {"unique_id": unique_id, "weapon_id": weapon_id, "combat_deck": combat_deck.to_dictionary(), "reserve_deck": reserve_deck.to_dictionary()}

# 恢复不读取起始数组，不生成或补充卡牌。
static func from_dictionary(data: Variant, cards: Dictionary, weapons: Dictionary) -> WeaponInstance:
	if not data is Dictionary or not data.get("unique_id") is String or data["unique_id"].is_empty():
		return null
	var id: Variant = data.get("weapon_id")
	if not (id is int or id is float) or int(id) != id or id <= 0:
		return null
	var weapon: WeaponInstance = load("res://Scripts/RefCounted/WeaponInstance.gd").new(int(id), weapons.get(int(id)), data["unique_id"])
	if weapon.weapon_data == null:
		push_warning("[WeaponInstance] 缺少 WeaponData ID %d；保留已存武器身份与双牌组，不重建初始内容。" % weapon.weapon_id)
	weapon.combat_deck = CardContainer.from_dictionary(data.get("combat_deck"), cards, COMBAT_LIMIT)
	weapon.reserve_deck = CardContainer.from_dictionary(data.get("reserve_deck"), cards)
	if weapon.combat_deck == null or weapon.reserve_deck == null:
		return null
	return weapon
