# 实例化的卡牌
class_name CardInstance
extends RefCounted

var base_id: int          # 静态数据的ID，存档时只需存这个
var base_data: CardData   # 原始卡牌数据
var modifiers: Array      # 修改器列表
var unique_id: String     # 实例卡牌UID

# 初始化
func _init(id: int):
	base_id = id
	# 从 AllCardData 中获取静态模板
	var db = AllCardData.get_cards()
	if db.has(id):
		base_data = db[id]
	else:
		push_error("CardInstance 初始化失败！找不到卡牌 ID: ", id)
		
	# 赋予UID
	unique_id = str(Time.get_ticks_usec()) + "_" + str(randi() % 1000)
	modifiers = []

# 公开方法：序列化（将自己打包成字典存入本地文件）
func to_dict() -> Dictionary:
	return {
		"base_id": base_id,
		"modifiers": modifiers.duplicate(true), # 深拷贝，防止引用污染
		"unique_id": unique_id
	}

# 反序列化（从本地存档字典中复原自己，这是一个静态方法）
static func from_dict(data: Dictionary) -> CardInstance:
	var instance = CardInstance.new(data["base_id"])
	instance.modifiers = data.get("modifiers", [])
	instance.unique_id = data.get("unique_id", "")
	return instance

# 获取卡牌名称
func get_card_name() -> String:
	if base_data:
		return base_data.name
	return "未知卡牌"
