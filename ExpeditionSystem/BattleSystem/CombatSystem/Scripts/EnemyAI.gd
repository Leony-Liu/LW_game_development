class_name EnemyAI
extends Node

# 动作生成信号：向上级抛出打包完毕的强类型行动数据
signal action_planned(action: CombatAction)

# 动作池缓存（由 EnemyData 注入）
var _action_pool: Array[EnemyAction] = []
# 施法者与目标标识
var _caster_id: String = "enemy"
var _target_id: String = "player"

# 冷却追踪器：记录每个 action_id 允许再次释放的绝对时间刻度
var _cooldown_tracker: Dictionary = {}
# 规划指针：记录 AI 已经预定动作的最晚时间刻度，防止多动作重叠在同一时刻
var _last_planned_time: int = 0


#region 初始化与配置

# 由 EntityManager 在装载敌人数据时调用，注入技能池并重置冷却状态
func setup_ai(action_pool: Array[EnemyAction], entity_id: String = "enemy", target_id: String = "player") -> void:
	_action_pool = action_pool
	_caster_id = entity_id
	_target_id = target_id
	_cooldown_tracker.clear()
	_last_planned_time = 0

	# 战斗开始时所有技能初始冷却完毕
	for action in _action_pool:
		_cooldown_tracker[action.action_id] = 0

# 战斗启动时由 EntityManager 调用，生成第一批敌人行动
func plan_initial_actions() -> void:
	plan_next_action(0)

#endregion


#region 决策与行动生成

# 核心决策逻辑：输入当前时间刻度，通过权重抽取技能并向上抛出 CombatAction
func plan_next_action(current_timeline_time: int) -> void:
	if _action_pool.is_empty():
		return

	# 确保规划起点不早于时间轴当前时间
	var current_plan_start = maxi(current_timeline_time, _last_planned_time)

	# 1. 筛选当前时间已冷却完毕的可用动作
	var available_actions: Array[EnemyAction] = []
	var total_weight: float = 0.0

	for action in _action_pool:
		var ready_time: int = _cooldown_tracker.get(action.action_id, 0)
		if current_plan_start >= ready_time:
			available_actions.append(action)
			total_weight += action.weight

	# 若技能全部在冷却中，时间指针向后推迟缓冲期后退出
	if available_actions.is_empty():
		_last_planned_time = current_plan_start + 10
		return

	# 2. 轮盘赌加权随机抽取行动
	var roll = randf() * total_weight
	var selected_action: EnemyAction = available_actions[0]
	for action in available_actions:
		roll -= action.weight
		if roll <= 0:
			selected_action = action
			break

	# 3. 计算触发时间并生成强类型的 CombatAction
	var target_time = current_plan_start + selected_action.time_cost
	var combat_action = _create_combat_action_from_enemy_action(selected_action, target_time)

	# 4. 更新内部时间刻度与冷却时间
	_last_planned_time = target_time
	_cooldown_tracker[selected_action.action_id] = target_time + selected_action.cooldown

	# 5. 向上汇报生成的动作
	action_planned.emit(combat_action)

# 将配置资源 EnemyAction 转译为运行时的标准 CombatAction
func _create_combat_action_from_enemy_action(enemy_action: EnemyAction, trigger_time: int) -> CombatAction:
	var action = CombatAction.new()
	action.action_name = enemy_action.action_name
	action.source_id = _caster_id
	action.target_id = _target_id
	action.is_player = false
	action.trigger_time = trigger_time
	action.priority = 1 # 敌人基础行动优先级

	# 解析具体行动效果并塞入原子数据载荷
	match enemy_action.action_type:
		"attack":
			var dmg = float(enemy_action.effect_data.get("damage", 10.0))
			action.add_attribute_impact("hp", -dmg) # 扣减目标生命

		"buff":
			# 示例：如果是加盾技能
			var shield_val = float(enemy_action.effect_data.get("shield", 0.0))
			if shield_val > 0:
				action.target_id = _caster_id # 给自身套盾
				action.add_attribute_impact("shield", shield_val)

		"skill":
			# 预留特殊效果处理（如对玩家卡牌施加 Buff 等）
			pass

	return action

#endregion
