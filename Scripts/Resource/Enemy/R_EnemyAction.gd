class_name EnemyAction
extends Resource

@export var action_id: String = "default_strike"
@export var action_name: String = "未命名行动"
@export var time_cost: int = -1 # 动作所需的准备/执行时间
@export var cooldown: int = -1# 施放后需要经过多少逻辑时间才能再次抽取
@export var weight: float = -1 # AI 随机抽取的权重
@export_enum("attack", "buff", "skill") var action_type: String = "attack"
@export var effect_data: Dictionary = {} 
