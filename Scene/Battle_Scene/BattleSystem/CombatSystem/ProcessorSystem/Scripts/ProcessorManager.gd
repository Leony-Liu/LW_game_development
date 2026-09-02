class_name ProcessorManager
extends Node

signal visual_effect_generated(effect_data: Dictionary)

@export var player_entity: CombatEntity
@export var enemy_entity: CombatEntity

func _ready() -> void:
	# 绑定下级请求视觉表现的信号，直接转发给顶层CombatManager
	if player_entity:
		player_entity.visual_requested.connect(_on_entity_visual_requested)
	if enemy_entity:
		enemy_entity.visual_requested.connect(_on_entity_visual_requested)

# 接收 EntityData
func initialize_entities(player_data: EntityData, enemy_data: EnemyData) -> void:
	if player_entity and player_data:
		player_entity.initialize_stats(player_data.base_attributes)
		
	if enemy_entity and enemy_data:
		# 拆包：仅将 base_attributes 字典抽出来塞给底层 Entity
		enemy_entity.initialize_stats(enemy_data.base_attributes)

# 接收 CombatAction，并判断作用于谁
func accept_action(action: CombatAction) -> void:
	var effect = action.effect_data
	var effect_type = effect.get("type", "")
	
	# 作为中介，通过判断 action 来源，将影响分发给对方或自己
	if action.is_player:
		if effect_type == "attack":
			enemy_entity.apply_effect(effect)
		elif effect_type == "buff":
			player_entity.apply_effect(effect)
		elif effect_type == "pay_cost": # 新增：处理扣除资源指令
			player_entity.apply_effect(effect)
	else:
		if effect_type == "attack":
			player_entity.apply_effect(effect)
		elif effect_type == "buff":
			enemy_entity.apply_effect(effect)
		elif effect_type == "pay_cost": # 新增：预留给敌人的扣除资源指令
			enemy_entity.apply_effect(effect)

func _on_entity_visual_requested(effect_data: Dictionary) -> void:
	visual_effect_generated.emit(effect_data)
