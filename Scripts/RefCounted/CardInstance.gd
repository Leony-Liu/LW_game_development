## 保存具体卡牌的身份、静态模板与长期修改器。
## 模板由创建者注入，不访问场景树或全局数据库。
class_name CardInstance
extends RefCounted

var card_id: int          # 静态数据的ID
var card_data: CardData   # 原始卡牌数据
var modifiers: Array      # 修改器列表
var unique_id: String     # 实例卡牌UID

# 初始化这张牌的所有数据
func _init(id: int, template: CardData) -> void:
	card_id = id
	if template == null or template.id != id:
		push_error("CardInstance: 必须注入与 card_id 匹配的 CardData。")
		return
	card_data = template
		
	# 赋予UID
	unique_id = str(Time.get_ticks_usec()) + "_" + str(randi() % 1000)
	modifiers = []

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
	if template == null or template.id != id:
		push_error("CardInstance: 无法恢复卡牌，缺少匹配的 CardData。")
		return null
	var instance = CardInstance.new(id, template)
	instance.modifiers = data.get("modifiers", []).duplicate(true)
	instance.unique_id = data.get("unique_id", "")
	return instance

# 获取卡牌名称
func get_card_name() -> String:
	if card_data:
		return card_data.name
	return "未知卡牌"
