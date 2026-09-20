class_name EntityData
extends RefCounted

# 实体唯一标识
var entity_id: String = ""
var entity_name: String = ""

# 核心生命与防御属性
var max_hp: float = 100.0
var current_hp: float = 100.0
var shield: float = 0.0

# 资源类属性
var max_stamina: float = 10.0
var current_stamina: float = 10.0
var stamina_regen_rate: float = 1.0 # 随时间每秒/每步回复量

var max_mana: float = 5.0
var current_mana: float = 5.0
var mana_regen_rate: float = 0.5

# 预留自定义拓展属性字典（仅用于特殊被动、特殊抗性等非标准字段）
var custom_properties: Dictionary = {}

func _init(id: String = "default_entity", name: String = "Unknown") -> void:
	entity_id = id
	entity_name = name

# 将定义好的标准属性解包为键值对，供 AttributeSet 统一批量注册
func export_to_attribute_map() -> Dictionary:
	var map: Dictionary = {
		"max_hp": max_hp,
		"hp": current_hp,
		"shield": shield,
		"max_stamina": max_stamina,
		"stamina": current_stamina,
		"stamina_regen": stamina_regen_rate,
		"max_mana": max_mana,
		"mana": current_mana,
		"mana_regen": mana_regen_rate
	}
	# 合并自定义拓展属性
	for key in custom_properties.keys():
		map[key] = custom_properties[key]
	return map
