## 定义敌人的静态身份、战斗参数与胜利奖励。
## 实例状态和奖励结算由使用方管理。
class_name EnemyData
extends Resource

# 敌人ID
@export var enemy_id: int
# 敌人显示名称
@export var enemy_name: String
# 敌人等级
@export var enemy_level : int
# 胜利时发放的 Soul；零表示无奖励，负值拒绝结算。
@export var soul_reward: int = 2
# 要生成的敌人属性
@export var attributes: Dictionary = {
	"hp": 100.0,
}
# 敌人行动池
@export var action_pool: Array[EnemyAction] = []
