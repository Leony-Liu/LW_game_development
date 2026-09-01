class_name ProcessorManager
extends Node

# 实现的功能：整个中枢的核心，唯一知道敌我实体的节点。解析 CombatAction，决定并调用正确的下级Entity的方法（V字中介交流）。
# 使用方法：挂载在CombatManager下，在检查器中绑定好场景内的player和enemy实体节点。

signal visual_effect_generated(effect_data: Dictionary)

@export var player_entity: CombatEntity
@export var enemy_entity: CombatEntity

func _ready() -> void:
	# 绑定下级请求视觉表现的信号，直接转发给顶层CombatManager
	if player_entity:
		player_entity.visual_requested.connect(_on_entity_visual_requested)
	if enemy_entity:
		enemy_entity.visual_requested.connect(_on_entity_visual_requested)

# 唯一接收外部（CombatManager）调用的入口
func accept_action(action: CombatAction) -> void:
	var effect = action.effect_data
	var effect_type = effect.get("type", "")
	
	# 作为中介，通过判断 action 来源，将影响分发给对方或自己
	if action.is_player:
		if effect_type == "attack":
			enemy_entity.apply_effect(effect)
		elif effect_type == "buff":
			player_entity.apply_effect(effect)
	else:
		if effect_type == "attack":
			player_entity.apply_effect(effect)
		elif effect_type == "buff":
			enemy_entity.apply_effect(effect)

func _on_entity_visual_requested(effect_data: Dictionary) -> void:
	visual_effect_generated.emit(effect_data)
