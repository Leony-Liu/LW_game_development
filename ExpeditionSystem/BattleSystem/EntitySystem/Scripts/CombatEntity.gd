class_name CombatEntity
extends Node

# 视觉需求信号，向 EntityManager / BattleManager 发出明确的表现请求
signal visual_requested(visual_type: String, data: Dictionary)
# 实体阵亡信号
signal entity_died(entity: CombatEntity)

@export var entity_id: String = ""
@export var is_player: bool = false
@export var attribute_set: AttributeSet

func _ready() -> void:
	if attribute_set:
		attribute_set.attribute_updated.connect(_on_attribute_updated)

# 根据 EntityData 解包出来的属性字典初始化 AttributeSet
func initialize_from_data(data: EntityData) -> void:
	entity_id = data.entity_id
	var stats = data.export_to_attribute_map()
	for key in stats.keys():
		attribute_set.register_attribute(key, stats[key])

# 执行数值变更：将 CombatAction 中的单个属性冲击应用到 AttributeSet
func apply_attribute_impact(impact: CombatAction.AttributeImpact) -> void:
	var attr_name = impact.attribute_name
	var val = impact.value
	
	# 特殊伤害结算逻辑：扣减生命前优先扣除护盾
	if attr_name == "hp" and val < 0:
		var incoming_damage = absf(val)
		var shield_attr = attribute_set.get_attribute("shield")
		
		if shield_attr and shield_attr.get_value() > 0:
			var current_shield = shield_attr.get_value()
			if current_shield >= incoming_damage:
				shield_attr.sub_base(incoming_damage)
				incoming_damage = 0.0
			else:
				incoming_damage -= current_shield
				shield_attr.sub_base(current_shield)
		
		# 穿透护盾后的实际伤害扣减血量
		if incoming_damage > 0:
			var hp_attr = attribute_set.get_attribute("hp")
			if hp_attr:
				hp_attr.sub_base(incoming_damage)
		
		visual_requested.emit("take_damage", {"entity": self, "damage": absf(val)})
		return

	# 通用属性增减（正数累加，负数扣除）
	var target_attr = attribute_set.get_attribute(attr_name)
	if target_attr:
		if val >= 0:
			target_attr.add_base(val)
		else:
			target_attr.sub_base(absf(val))
			
	visual_requested.emit("attribute_impacted", {"entity": self, "attribute": attr_name, "value": val})

# 为指定属性附加实体 Buff
func apply_entity_buff(attr_name: String, buff: AttributeBuff) -> void:
	var target_attr = attribute_set.get_attribute(attr_name)
	if target_attr:
		target_attr.add_buff(buff)
		visual_requested.emit("buff_applied", {"entity": self, "attribute": attr_name})

# 监听 AttributeSet 的底层属性变动
func _on_attribute_updated(attribute_name: String, old_value: float, new_value: float) -> void:
	visual_requested.emit("update_ui", {
		"entity": self,
		"attribute": attribute_name,
		"old_value": old_value,
		"new_value": new_value
	})
	
	# 生命值归零判定死亡
	if attribute_name == "hp" and new_value <= 0:
		entity_died.emit(self)
