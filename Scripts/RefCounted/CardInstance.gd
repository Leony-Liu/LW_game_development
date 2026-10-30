## 保存具体卡牌的身份、静态模板与长期修改器。
## 模板由创建者注入，不访问场景树或全局数据库。
class_name CardInstance
extends RefCounted

var card_id: int          # 静态数据的ID
var card_data: CardData   # 原始卡牌数据
var modifiers: Array      # 修改器列表
var unique_id: String     # 实例卡牌UID
var container_ref: WeakRef # 所属容器的弱引用，避免循环持有。

# 初始化这张牌的所有数据
func _init(id: int, template: CardData, instance_uid: String = "") -> void:
	card_id = id
	if id <= 0 or (template != null and template.id != id):
		push_error("CardInstance: 必须注入与 card_id 匹配的 CardData。")
		return
	card_data = template
		
	# 恢复时保留原身份；新实例使用 256 位安全随机值。
	if instance_uid.strip_edges().is_empty():
		unique_id = Crypto.new().generate_random_bytes(32).hex_encode()
	else:
		unique_id = instance_uid
	modifiers = []

# 复制同一身份的独立表示；所属容器由新容器重新绑定。
func clone() -> CardInstance:
	if card_id <= 0 or unique_id.strip_edges().is_empty() or (card_data != null and card_data.id != card_id):
		push_error("[CardInstance] 复制失败：卡牌身份或模板无效。")
		return null
	if not _can_copy_modifier_value(modifiers):
		push_error("[CardInstance] 复制失败：modifiers 含对象引用或过深嵌套，无法保证独立副本。")
		return null
	var copied := CardInstance.new(card_id, card_data, unique_id)
	copied.modifiers = modifiers.duplicate(true)
	return copied

# 修改器只复制值与嵌套集合，拒绝隐式共享对象及循环结构。
func _can_copy_modifier_value(value: Variant, depth: int = 0) -> bool:
	if depth > 64 or typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]:
		return false
	if value is Array:
		for item in value:
			if not _can_copy_modifier_value(item, depth + 1):
				return false
	elif value is Dictionary:
		for key in value:
			if not _can_copy_modifier_value(key, depth + 1) or not _can_copy_modifier_value(value[key], depth + 1):
				return false
	return true

# 公开方法：序列化，将数据变成字典
func to_dictionary() -> Dictionary:
	return {
		"card_id": card_id,
		"modifiers": modifiers.duplicate(true), # 深拷贝，防止引用污染
		"unique_id": unique_id
	}

# 反序列化，将字典变成一个卡牌实例
static func from_dictionary(data: Dictionary, template: CardData) -> CardInstance:
	var id := int(data.get("card_id", 0))
	if id <= 0 or (template != null and template.id != id):
		push_error("CardInstance: 无法恢复卡牌，缺少匹配的 CardData。")
		return null
	if template == null:
		push_warning("[CardInstance] 缺少 CardData ID %d；保留持久身份与修改器，战斗时跳过。" % id)
	var saved_uid: Variant = data.get("unique_id", "")
	var instance_uid: String = saved_uid if saved_uid is String else ""
	var instance = CardInstance.new(id, template, instance_uid)
	if instance_uid.strip_edges().is_empty():
		push_warning("[CardInstance] 恢复数据缺少有效 unique_id，已为旧卡牌生成替代身份。")
	instance.modifiers = data.get("modifiers", []).duplicate(true)
	return instance

# 获取卡牌名称
func get_card_name() -> String:
	if card_data:
		return card_data.name
	return "未知卡牌"
