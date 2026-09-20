class_name EnemyData
extends Resource

# 敌人ID
@export var enemy_id: int
# 敌人显示名称
@export var enemy_name: String
# 敌人等级
@export var enemy_level : int
# 要生成的敌人属性
@export var attributes: Dictionary = {
	"hp": 100.0,
}
# 敌人行动池
@export var action_pool: Array[EnemyAction] = []
