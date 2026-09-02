class_name EnemyData
extends Resource

@export var enemy_id: int
@export var enemy_name: String
@export var attributes: Dictionary = {
	"hp": 100.0,
	"max_hp": 100.0,
	"strength": 0.0
}
@export var action_pool: Array[EnemyAction] = []
