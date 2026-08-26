class_name TimelineEvent
extends RefCounted

var timestamp: int       # 发生的时间点
var source: BattleEntity # 发起者
var target: BattleEntity # 目标
var action_name: String  # 动作名称（供输出显示）
var effect: Callable     # 具体的执行逻辑
var is_valid: bool = true # 是否有效（被打断或死亡则置为 false）

func _init(t: int, s: BattleEntity, tgt: BattleEntity, n: String, e: Callable):
	timestamp = t
	source = s
	target = tgt
	action_name = n
	effect = e
