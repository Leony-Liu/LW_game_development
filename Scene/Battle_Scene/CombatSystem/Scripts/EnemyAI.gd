class_name EnemyAI
extends Node

@export var max_predict_time: int = 200

# 规划行动，确保时间轴上敌人的行动覆盖到 current_time + max_predict_time
func plan_actions(timeline: Timeline):
	var target_coverage_time = timeline.current_time + max_predict_time
	var last_action_time = timeline.get_last_enemy_action_time()
	
	# 如果时间轴上的敌人行动还不够 200，则继续生成
	while last_action_time < target_coverage_time:
		var next_action = _generate_next_action(last_action_time)
		# 触发时间轴添加行动，并把计算好的行动填入
		timeline.add_action(next_action)
		last_action_time = next_action.trigger_time

# TODO 生成一个行动（目前为硬编码，未接入敌人数据）
func _generate_next_action(last_time: int) -> CombatAction:
	var action = CombatAction.new()
	action.is_player = false
	# 举例：随机生成一个行为
	if randf() > 0.5:
		action.action_name = "敌人攻击"
		action.trigger_time = last_time + 40 # 占用时长40
		action.priority = 1
		action.effect_data = {"type": "attack", "damage": 5}
	else:
		action.action_name = "敌人强化"
		action.trigger_time = last_time + 30 # 占用时长30
		action.priority = 2
		action.effect_data = {"type": "buff", "amount": 2}
	return action
