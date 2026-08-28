class_name CombatAction
extends RefCounted

# 行动名称
var action_name: String
# 触发时间
var trigger_time: int
# 优先级
var priority: int
# 发起方
var is_player: bool
# 效果数据
var effect_data: Dictionary # 存放具体效果的参数，如 {"type": "attack", "damage": 10} 或 {"type": "stun"}

# 用于时间轴排序的静态方法
static func sort_actions(a: CombatAction, b: CombatAction) -> bool:
	if a.trigger_time != b.trigger_time:
		return a.trigger_time < b.trigger_time # 时间早的优先
	if a.priority != b.priority:
		return a.priority > b.priority         # 优先级高的优先
	return a.is_player                         # 同时间同优先级，玩家优先 
