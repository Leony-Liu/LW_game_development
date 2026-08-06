class_name TimelineAction
extends RefCounted

enum ActorSide{
	PLAYER,
	ENEMY,
	UNKOWN
}

# 行动序号ID
var sequence_id : int = -1
# 行动名称
var action_name : String = ""
# 行动发起者
var actor_side : int = ActorSide.UNKOWN
# 行动发起节点
var actor : Node

# —————— 固定时间变量 ——————
# 行动消耗的时长
var time_cost : int = -1
# 行动执行时间（一般给敌人使用）
var execute_time : int = -1
# 执行优先级(1~3级，3级最高)
var execute_priority : int = -1
# 是否推进时间
var advances_time : bool = false
# 是否能被取消
var can_be_cancelled : bool = true
# 被取消状态
var is_cancelled : bool = false
# 取消原因
var cancel_reason : String = ""

# —————— 机制变量 ——————
# 先手属性
var has_initiative : bool = false

var payload : Dictionary = {}

# 方便创建行动时一次完成设置
func setup(
	new_action_name: StringName,
	new_actor: Node,
	new_actor_side: int,
	new_time_cost: int,
	new_execute_priority: int = 1,
	new_has_initiative: bool = false,
	new_advances_time: bool = false,
	new_payload: Dictionary = {}
) -> TimelineAction:
	action_name = new_action_name
	actor = new_actor
	actor_side = new_actor_side
	time_cost = max(new_time_cost, 0)
	execute_priority = clampi(new_execute_priority, 0, 3)
	has_initiative = new_has_initiative
	advances_time = new_advances_time
	payload = new_payload.duplicate(true)

	return self



# 取消一个行动
func cancel(reason: StringName) -> void:
	if not can_be_cancelled:
		print("timeline_action:该行动无法取消")
		return

	is_cancelled = true
	cancel_reason = reason

# 获取是否已被安排执行
func is_scheduled() -> bool:
	return execute_time >= 0

# 获取到执行还剩余的时间
func get_remaining_time(current_time: int) -> int:
	return maxi(execute_time - current_time, 0)
