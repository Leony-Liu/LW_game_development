extends Node
class_name EnemyAI


@onready var data_source: Node = get_node_or_null("EnemyTestData")


var action_database: Dictionary = {}

var category_weights: Dictionary = {}

var opening_patterns: Array = []
# 当前战斗随机选择的开局序列
var opening_queue: Array[String] = []


# =========================================================
# AI 运行数据
# =========================================================
# 已规划时间
var planned_until_time: int = 0
# 上一次生成的行动 ID
var last_action_id: String = ""
# 数据是否已经成功加载
var data_loaded: bool = false
# 当前是否正在生成行动
var is_generating: bool = false

# 每次规划请求最多生成多少个行动
const MAX_ACTIONS_PER_REQUEST: int = 100
# 随机数生成器
var random_generator := RandomNumberGenerator.new()


# =========================================================
# 生命周期
# =========================================================

func _ready() -> void:
	random_generator.randomize()

	_load_data_from_child()


# =========================================================
# 输入一：读取敌人数据
# =========================================================
# 读取敌人数据内置方法
func _load_data_from_child() -> void:
	if data_source == null:
		push_error("EnemyAI：找不到子节点 EnemyTestData")
		return

	if not data_source.has_method("get_ai_config"):
		push_error("EnemyAI：EnemyTestData 缺少 " + "get_ai_config() 方法")
		return

	var raw_config = data_source.call("get_ai_config")

	if typeof(raw_config) != TYPE_DICTIONARY:
		push_error("EnemyAI：get_ai_config() " + "必须返回 Dictionary")
		return

	set_enemy_data(raw_config)


#  EnemyAI 正式数据输入接口
func set_enemy_data(enemy_config: Dictionary) -> bool:
	data_loaded = false

	action_database.clear()
	category_weights.clear()
	opening_patterns.clear()
	opening_queue.clear()

	last_action_id = ""

	# 默认认为战斗时间从 0 开始。
	planned_until_time = int(enemy_config.get("plan_start_time",0))

	_read_action_database(enemy_config.get("actions",{}))

	_read_category_weights(enemy_config.get("category_weights",{}))

	_read_opening_patterns(enemy_config.get("opening_patterns",[]))

	if action_database.is_empty():
		push_error("EnemyAI：敌人数据中没有有效的 actions")
		return false

	if category_weights.is_empty():
		push_error("EnemyAI：敌人数据中没有 " + "category_weights")
		return false

	_choose_opening_pattern()

	data_loaded = true

	print("EnemyAI：数据加载完成，行动数量：",action_database.size())

	return true

# 读取并整理行动数据库。
func _read_action_database(raw_actions) -> void:
	if typeof(raw_actions) != TYPE_DICTIONARY:
		return

	var actions: Dictionary = raw_actions

	for raw_action_id in actions.keys():
		var raw_action_data = actions.get(raw_action_id,{})

		if typeof(raw_action_data) != TYPE_DICTIONARY:
			continue

		var action_id: String = str(raw_action_id)

		var action_data: Dictionary = (raw_action_data.duplicate(true))
		# 数据内部没有 id 时，
		# 自动使用外层字典的键。
		action_data["id"] = str(action_data.get("id",action_id))

		action_data["category"] = str(action_data.get("category",""))

		action_database[action_id] = action_data


# 读取类别权重。
func _read_category_weights(raw_weights) -> void:
	if typeof(raw_weights) != TYPE_DICTIONARY:
		return

	var weights: Dictionary = raw_weights

	for raw_category in weights.keys():
		var category: String = str(raw_category)

		var weight: float = float(weights.get(raw_category,0.0))

		category_weights[category] = maxf(weight,0.0)


# 读取开局行动序列。
func _read_opening_patterns(raw_patterns) -> void:
	if typeof(raw_patterns) != TYPE_ARRAY:
		return

	for raw_pattern in raw_patterns:
		if typeof(raw_pattern) != TYPE_ARRAY:
			continue

		var pattern: Array[String] = []

		for raw_action_id in raw_pattern:
			pattern.append(str(raw_action_id))

		if not pattern.is_empty():
			opening_patterns.append(pattern)


# =========================================================
# 输入二：接收 ATM 的规划请求
# =========================================================

# 
func on_plan_requested(required_until_time: int) -> void:
	if not data_loaded:
		push_warning("EnemyAI：收到规划请求，"+ "但敌人数据尚未加载")
		return

	if required_until_time <= planned_until_time:
		return

	if is_generating:
		return

	_generate_actions_until(required_until_time)


# =========================================================
# 生成未来行动
# =========================================================

func _generate_actions_until(required_until_time: int) -> void:
	is_generating = true

	var generated_count: int = 0

	while planned_until_time < required_until_time:
		if (generated_count>= MAX_ACTIONS_PER_REQUEST):
			push_error("EnemyAI：一次规划生成了过多行动，" + "请检查行动 time_cost")
			break

		var action_id: String = (_choose_next_action())

		if action_id.is_empty():
			push_warning("EnemyAI：没有可以生成的行动")
			break

		var action_data: Dictionary = (action_database.get(action_id,{}))

		if action_data.is_empty():
			push_error("EnemyAI：找不到行动数据：" + action_id)
			break

		var time_cost: int = int(action_data.get("time_cost",0))

		if time_cost <= 0:
			push_error("EnemyAI：行动 "+ action_id+ " 的 time_cost 必须大于 0")
			break

		# 新行动接在上一个行动后面。
		var execute_time: int = (planned_until_time + time_cost)

		var timeline_action := (_create_timeline_action(action_id,action_data,execute_time))

		if timeline_action == null:
			break

		# 唯一输出：
		# 将生成的行动提交给战斗总线。
		BattleBus.action_committed.emit(timeline_action)

		planned_until_time = execute_time
		last_action_id = action_id
		generated_count += 1

	is_generating = false

	print("EnemyAI：本次生成 ",generated_count," 个行动，规划到时间 ",planned_until_time)

# =========================================================
# 选择行动
# =========================================================

func _choose_next_action() -> String:
	# 开局队列还没有用完时，
	# 优先使用开局行动。
	while not opening_queue.is_empty():
		var opening_action_id: String = (opening_queue.pop_front())

		if _is_action_valid(opening_action_id,false):
			return opening_action_id

	# 开局行动结束后，
	# 使用权重随机。
	return _choose_weighted_action()


# 随机选择一套开局行动。
func _choose_opening_pattern() -> void:
	opening_queue.clear()

	if opening_patterns.is_empty():
		return

	var selected_index: int = (
		random_generator.randi_range(0,opening_patterns.size() - 1))

	var selected_pattern: Array = (opening_patterns[selected_index])

	for action_id in selected_pattern:
		opening_queue.append(str(action_id))

	print("EnemyAI：本场开局行动：",opening_queue)


# 根据最终权重随机选择行动。
func _choose_weighted_action() -> String:
	var candidates: Array[Dictionary] = []
	var total_weight: float = 0.0

	for raw_action_id in action_database.keys():
		var action_id: String = str(raw_action_id)

		if not _is_action_valid(action_id,true):
			continue

		var action_data: Dictionary = (action_database.get(action_id,{}))

		var action_weight: float = (_get_action_weight(action_data))

		if action_weight <= 0.0:
			continue

		candidates.append({
			"id": action_id,
			"weight": action_weight
		})

		total_weight += action_weight

	# 有可能所有行动都因为
	# cannot_repeat 被过滤掉。
	#
	# 这种情况下再选择一次，
	# 但忽略“不能连续使用”的限制。
	if candidates.is_empty():
		return _choose_weighted_action_without_repeat_rule()

	if total_weight <= 0.0:
		return ""

	var roll: float = (
		random_generator.randf()
		* total_weight
	)

	for candidate: Dictionary in candidates:
		roll -= float(
			candidate.get(
				"weight",
				0.0
			)
		)

		if roll <= 0.0:
			return str(
				candidate.get(
					"id",
					""
				)
			)

	return str(
		candidates.back().get(
			"id",
			""
		)
	)


# 当“禁止连续行动”导致没有候选项时，
# 使用这个兜底选择。
func _choose_weighted_action_without_repeat_rule() -> String:
	var candidates: Array[Dictionary] = []
	var total_weight: float = 0.0

	for raw_action_id in action_database.keys():
		var action_id: String = str(
			raw_action_id
		)

		if not _is_action_valid(
			action_id,
			false
		):
			continue

		var action_data: Dictionary = (
			action_database.get(
				action_id,
				{}
			)
		)

		var action_weight: float = (
			_get_action_weight(
				action_data
			)
		)

		if action_weight <= 0.0:
			continue

		candidates.append({
			"id": action_id,
			"weight": action_weight
		})

		total_weight += action_weight

	if candidates.is_empty():
		return ""

	if total_weight <= 0.0:
		return ""

	var roll: float = (
		random_generator.randf()
		* total_weight
	)

	for candidate: Dictionary in candidates:
		roll -= float(
			candidate.get(
				"weight",
				0.0
			)
		)

		if roll <= 0.0:
			return str(
				candidate.get(
					"id",
					""
				)
			)

	return str(
		candidates.back().get(
			"id",
			""
		)
	)


# =========================================================
# 行动权重
# =========================================================

# 最终行动权重：
#
# 类别权重 × 类别内部行动权重
#
# 例如：
#
# 攻击类别权重 = 0.6
# 普通攻击内部权重 = 0.5
#
# 普通攻击最终权重：
# 0.6 × 0.5 = 0.3
func _get_action_weight(
	action_data: Dictionary
) -> float:
	var category: String = str(
		action_data.get(
			"category",
			""
		)
	)

	var category_weight: float = float(
		category_weights.get(
			category,
			0.0
		)
	)

	var internal_weight: float = float(
		action_data.get(
			"weight",
			0.0
		)
	)

	return maxf(
		category_weight
		* internal_weight,
		0.0
	)


# =========================================================
# 行动有效性
# =========================================================

func _is_action_valid(
	action_id: String,
	check_repeat_rule: bool
) -> bool:
	var action_data: Dictionary = (
		action_database.get(
			action_id,
			{}
		)
	)

	if action_data.is_empty():
		return false

	# enabled = false 时，
	# 这个行动不会被生成。
	if not bool(
		action_data.get(
			"enabled",
			true
		)
	):
		return false

	if int(
		action_data.get(
			"time_cost",
			0
		)
	) <= 0:
		return false

	# 数据中可以加入：
	#
	# "cannot_repeat": true
	#
	# 表示不能连续使用该行动。
	if check_repeat_rule:
		var cannot_repeat: bool = bool(
			action_data.get(
				"cannot_repeat",
				false
			)
		)

		if (
			cannot_repeat
			and action_id == last_action_id
		):
			return false

	return true


# =========================================================
# 创建 TimelineAction
# =========================================================

func _create_timeline_action(
	action_id: String,
	action_data: Dictionary,
	execute_time: int
) -> TimelineAction:
	var enemy_actor: Node = get_parent()

	if enemy_actor == null:
		push_error(
			"EnemyAI：找不到敌人根节点"
		)
		return null

	var action := TimelineAction.new()

	# 不在这里设置 sequence_id。
	# sequence_id 应由 ATM 分配。
	action.action_name = str(
		action_data.get(
			"name",
			action_id
		)
	)

	action.actor = enemy_actor

	action.actor_side = (
		TimelineAction.ActorSide.ENEMY
	)

	action.time_cost = int(
		action_data.get(
			"time_cost",
			0
		)
	)

	# EnemyAI 已经提前计算出的绝对执行时间。
	action.execute_time = execute_time

	action.execute_priority = clampi(
		int(
			action_data.get(
				"execute_priority",
				1
			)
		),
		0,
		3
	)

	# 敌人行动只进入未来时间轴，
	# 不主动推进整个战斗时间。
	action.advances_time = false

	action.can_be_cancelled = bool(
		action_data.get(
			"can_be_cancelled",
			true
		)
	)

	action.has_initiative = bool(
		action_data.get(
			"has_initiative",
			false
		)
	)

	# EnemyAI 不解释具体技能效果。
	#
	# 它只把行动数据放入 payload，
	# 等行动到期后由结算器读取。
	action.payload = {
		"action_id": action_id,

		"category": str(
			action_data.get(
				"category",
				""
			)
		),

		"effect_type": str(
			action_data.get(
				"effect_type",
				""
			)
		),

		# 例如：
		# "player"
		# "self"
		# "all_enemies"
		"target_type": str(
			action_data.get(
				"target_type",
				"player"
			)
		),

		# 保存完整数据副本。
		#
		# 伤害、持续时间、层数等参数，
		# 由后续行动结算器读取。
		"action_data": (
			action_data.duplicate(true)
		)
	}

	return action
