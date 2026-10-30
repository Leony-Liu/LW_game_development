## 保存有稳定身份的有序卡牌实例集合。
## 只负责容器内操作与序列化，不访问全局数据或创建玩法内容。
class_name CardContainer
extends RefCounted

var container_id: String
var capacity: int = -1
var _cards: Array[CardInstance] = []


# 容器身份由拥有者指定，并在恢复时沿用。
func _init(id: String, maximum: int = -1) -> void:
	container_id = id
	capacity = maximum


# 返回顺序副本，卡牌对象仍为原有实例。
func get_cards() -> Array[CardInstance]:
	return _cards.duplicate()


# 完整复制配置与有序卡牌；不继承旧容器归属或任何监听者。
func clone() -> CardContainer:
	if container_id.strip_edges().is_empty() or (capacity >= 0 and _cards.size() > capacity):
		push_error("[CardContainer] 复制失败：容器身份或容量无效。")
		return null
	var copied: CardContainer = load("res://Scripts/RefCounted/CardContainer.gd").new(container_id, capacity)
	for card in _cards:
		if card == null or card.container_ref == null or card.container_ref.get_ref() != self:
			push_error("[CardContainer] 复制失败：卡牌为空或所属容器不一致。")
			return null
		var copied_card := card.clone()
		if copied_card == null or not copied.add_card(copied_card):
			return null
	return copied


# 按实例身份查找，不以模板 ID 区分具体卡。
func find_card(uid: String) -> CardInstance:
	for card in _cards:
		if card.unique_id == uid:
			return card
	return null


# 在指定位置接收已有实例；负索引表示追加。
func add_card(card: CardInstance, index: int = -1) -> bool:
	if card == null or card.card_id <= 0 or (card.card_data != null and card.card_data.id != card.card_id):
		push_error("[CardContainer] 添加失败：卡牌或模板无效。")
		return false
	if card.container_ref != null and card.container_ref.get_ref() != null:
		push_warning("[CardContainer] 添加失败：卡牌已有所属容器，请使用 transfer_to。")
		return false
	if capacity >= 0 and _cards.size() >= capacity:
		push_warning("[CardContainer] 添加失败：%s 已达到容量 %d。" % [container_id, capacity])
		return false
	if card.unique_id.strip_edges().is_empty() or find_card(card.unique_id) != null:
		push_error("[CardContainer] 添加失败：实例 UID 为空或已存在于 %s。" % container_id)
		return false
	if index < -1 or index > _cards.size():
		push_error("[CardContainer] 添加失败：插入位置越界。")
		return false
	_cards.insert(_cards.size() if index == -1 else index, card)
	card.container_ref = weakref(self)
	return true


# 移除并返回同一个对象，未找到时返回 null。
func remove_card(uid: String) -> CardInstance:
	var card := find_card(uid)
	if card != null:
		_cards.erase(card)
		card.container_ref = null
	return card


# 先校验接收端，再移动原对象；失败时源容器保持不变。
func transfer_to(destination: CardContainer, uid: String, index: int = -1) -> bool:
	var card := find_card(uid)
	if destination == null or destination == self or card == null:
		push_error("[CardContainer] 转移失败：源卡牌或目标容器无效。")
		return false
	var original_index := _cards.find(card)
	remove_card(uid)
	if not destination.add_card(card, index):
		add_card(card, original_index)
		return false
	return true


# 输出稳定容器 ID 和有序卡牌字典。
func to_dictionary() -> Dictionary:
	var cards: Array[Dictionary] = []
	for card in _cards:
		cards.append(card.to_dictionary())
	return {"container_id": container_id, "cards": cards}


# 完整恢复后才返回新容器；无效条目使整个恢复失败。
static func from_dictionary(data: Variant, card_database: Dictionary, maximum: int = -1) -> CardContainer:
	if not data is Dictionary or not data.get("container_id") is String or not data.get("cards") is Array:
		push_error("[CardContainer] 恢复失败：缺少有效容器 ID 或 cards 数组。")
		return null
	if data["container_id"].strip_edges().is_empty():
		push_error("[CardContainer] 恢复失败：容器 ID 为空。")
		return null
	var container: CardContainer = load("res://Scripts/RefCounted/CardContainer.gd").new(data["container_id"], maximum)
	for entry in data["cards"]:
		if not entry is Dictionary or not entry.get("modifiers", []) is Array:
			push_error("[CardContainer] 恢复失败：卡牌条目或 modifiers 无效。")
			return null
		var raw_id: Variant = entry.get("card_id")
		if not (raw_id is int or raw_id is float) or int(raw_id) != raw_id:
			push_error("[CardContainer] 恢复失败：card_id 必须为整数。")
			return null
		var template := card_database.get(int(raw_id)) as CardData
		var card := CardInstance.from_dictionary(entry, template)
		if card == null or not container.add_card(card):
			return null
	return container
