class_name CombatEntity
extends Node

# 实现的功能：作为敌我实体的通用基类，持有 AttributeSet 并在其发生变化时，请求视觉表现。
# 使用方法：挂载在场景中。PlayerEntity 和 EnemyEntity 脚本只需继承此类即可（extends CombatEntity）。

signal visual_requested(effect_data: Dictionary)
signal entity_died(entity: CombatEntity)

@export var is_player: bool = false
@onready var attribute_set: AttributeSet = $AttributeSet

func _ready() -> void:
	if attribute_set:
		attribute_set.attribute_updated.connect(_on_attribute_updated)

func initialize_stats(stats_dict: Dictionary) -> void:
	for key in stats_dict.keys():
		attribute_set.register_attribute(key, stats_dict[key])

# 统一接收来自 Processor 的影响数据
func apply_effect(effect_data: Dictionary) -> void:
	var effect_type = effect_data.get("type", "")
	
	match effect_type:
		"attack":
			var dmg = effect_data.get("damage", 0)
			var hp_attr = attribute_set.get_attribute("hp")
			if hp_attr: hp_attr.sub_base(dmg)
			visual_requested.emit({"type": "take_damage_animation", "target": self, "value": dmg})
		"buff":
			# 示例：此处可解析数据生成 AttributeBuff 并交由 attribute_set 处理
			pass

func _on_attribute_updated(attr_name: String, old_value: float, new_value: float) -> void:
	# 向上报告UI更新需求
	visual_requested.emit({"type": "update_ui", "target": self, "attribute": attr_name, "value": new_value})
	
	if attr_name == "hp" and new_value <= 0:
		entity_died.emit(self)
