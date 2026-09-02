class_name EnemyAI
extends Node

var _enemy_data: EnemyData
# 核心状态：记录每个 action_id 再次可用的逻辑时间点
var _cooldown_tracker: Dictionary = {}
# 记录 AI 已经规划到的时间终点，防止 AI 在同一时间点堆叠无数个动作
var _last_planned_time: int = 0

# 由外部网关（如 CombatManager.initialize_combat）传入并初始化
func initialize(enemy_data: EnemyData) -> void:
	_enemy_data = enemy_data
	_cooldown_tracker.clear()
	_last_planned_time = 0
	
	if not _enemy_data: return
	# 初始状态下，所有技能的冷却完成时间均为 0（立刻可用）
	for action in _enemy_data.action_pool:
		_cooldown_tracker[action.action_id] = 0

# 战斗管理器调用，请求 AI 填补时间轴
func plan_actions(timeline: Timeline) -> void:
	if not _enemy_data or _enemy_data.action_pool.is_empty():
		return
		
	# 确保 AI 规划的起点不会早于当前时间
	var current_plan_start = max(timeline.current_time, _last_planned_time)
	
	# 1. 筛选出不在冷却中的可用动作
	var available_actions: Array[EnemyAction] = []
	var total_weight: float = 0.0
	
	for action in _enemy_data.action_pool:
		var ready_time = _cooldown_tracker.get(action.action_id, 0)
		if current_plan_start >= ready_time:
			available_actions.append(action)
			total_weight += action.weight
			
	# 如果全部在冷却中（比如全带长 CD），推迟一点时间再次尝试
	if available_actions.is_empty():
		_last_planned_time = current_plan_start + 10
		return
		
	# 2. 轮盘赌算法：根据权重随机抽取动作
	var roll = randf() * total_weight
	var selected_action: EnemyAction = available_actions[0]
	for action in available_actions:
		roll -= action.weight
		if roll <= 0:
			selected_action = action
			break
			
	# 3. 转译为 CombatAction 并推入时间轴
	var target_time = current_plan_start + selected_action.time_cost
	var combat_action = CombatAction.new()
	combat_action.is_player = false
	combat_action.action_name = selected_action.action_name
	combat_action.trigger_time = target_time
	combat_action.priority = 1
	
	# 将动作大类（attack/skill）合并进 effect_data 字典供 Processor 识别
	var final_effect = selected_action.effect_data.duplicate()
	if not final_effect.has("type"):
		final_effect["type"] = selected_action.action_type
	combat_action.effect_data = final_effect
	
	timeline.add_action(combat_action)
	
	# 4. 更新内部记录：推进规划指针，并为该技能附加新的冷却时间
	_last_planned_time = target_time
	_cooldown_tracker[selected_action.action_id] = target_time + selected_action.cooldown
