class_name Timeline
extends Node

# 战斗时间
var current_time: int = 0
# 行动队列
var action_line: Array[CombatAction] = []

# 添加行动并重新排序
func add_action(action: CombatAction):
	action_line.append(action)
	action_line.sort_custom(Callable(CombatAction, "sort_actions"))

# 获取并移除下一个在目标时间（含）之前的行动
func pop_next_action_before_or_equal(target_time: int) -> CombatAction:
	if action_line.is_empty():
		return null
	if action_line[0].trigger_time <= target_time:
		return action_line.pop_front()
	return null

# 获取当前队列中，敌人行动的最晚时间，帮助AI判断从何时开始追加
func get_last_enemy_action_time() -> int:
	var max_time = current_time
	for action in action_line:
		if not action.is_player and action.trigger_time > max_time:
			max_time = action.trigger_time
	return max_time

# 移除指定时间（含）之前的所有敌人行动
func clear_enemy_actions(target_time: int):
	# 逆序遍历安全移除
	for i in range(action_line.size() - 1, -1, -1):
		var action = action_line[i]
		# 如果不是玩家行动，且触发时间小于或等于目标时间
		if not action.is_player and action.trigger_time <= target_time:
			action_line.remove_at(i)
