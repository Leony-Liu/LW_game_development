# 实例化的卡牌
class_name CardInstance
extends RefCounted

var card_id: int          # 静态数据的ID
var card_data: CardData   # 原始卡牌数据
var modifiers: Array      # 修改器列表
var unique_id: String     # 实例卡牌UID

# 初始化这张牌的所有数据
func _init(id: int):
	card_id = id
	# 从 AllCardData 中获取静态模板
	var database = AllCardData.get_cards()
	if database.has(id):
		card_data = database[id]
	else:
		push_error("CardInstance 初始化失败！找不到卡牌 ID: ", id)
		
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
static func from_dictionary(data: Dictionary) -> CardInstance:
	var instance = CardInstance.new(data["card_id"])
	instance.modifiers = data.get("modifiers", [])
	instance.unique_id = data.get("unique_id", "")
	return instance

# 获取卡牌名称
func get_card_name() -> String:
	if card_data:
		return card_data.name
	return "未知卡牌"
