class_name EntityData
extends RefCounted

var entity_id: String
# 记录基础属性，如 {"hp": 100.0, "stamina": 3.0}
var base_attributes: Dictionary = {}

func _init(id: String = "default_entity", attributes: Dictionary = {}) -> void:
	entity_id = id
	# 深拷贝断开外部字典的引用，保证数据纯净
	base_attributes = attributes.duplicate(true)
