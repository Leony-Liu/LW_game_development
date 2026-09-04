class_name CombatEntity
extends Node

signal visual_requested(effect_data: Dictionary)
signal entity_died(entity: CombatEntity)

@export var is_player: bool = false
@export var attribute_set: AttributeSet

func _ready() -> void:
	if attribute_set:
		attribute_set.attribute_updated.connect(_on_attribute_updated)

# 注册属性
func initialize_stats(stats_dictionary: Dictionary) -> void:
	for key in stats_dictionary.keys():
		attribute_set.register_attribute(key, stats_dictionary[key])

# 接收 Processor 读取的 CombatAction 部分数据，确认行动的效果并执行
func apply_effect(effect_data: Dictionary) -> void:
	var effect_type = effect_data.get("type", "")
	
	match effect_type:
		"attack":
			var dmg = effect_data.get("damage", 0)
			var hp_attr = attribute_set.get_attribute("hp")
			if hp_attr: 
				hp_attr.sub_base(dmg)
			visual_requested.emit({"type": "take_damage_animation", "target": self, "value": dmg})
			
		"buff":
			# 示例：此处可解析数据生成 AttributeBuff 并交由 attribute_set 处理
			pass
			
		"pay_cost": # 新增：处理扣除资源的实际运算
			var cost_amount = effect_data.get("amount", 0)
			var stamina_attr = attribute_set.get_attribute("stamina")
			if stamina_attr:
				stamina_attr.sub_base(cost_amount)
			visual_requested.emit({"type": "pay_cost_animation", "target": self, "value": cost_amount})

# 实体属性变化上报
func _on_attribute_updated(attribute_name: String, old_value: float, new_value: float) -> void:
	# 向上报告UI更新需求
	visual_requested.emit({"type": "update_ui", "target": self, "attribute": attribute_name, "value": new_value})
	
	if attribute_name == "hp" and new_value <= 0:
		entity_died.emit(self)
