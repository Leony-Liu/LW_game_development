extends Node
class_name EnemyAI

@onready var data_source: Node = get_node_or_null("EnemyTestData")

var action_database: Dictionary = {}
var category_weights: Dictionary = {}
var opening_patterns: Array = []
# 当前战斗随机选择的开局序列
var opening_queue: Array[String] = []

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


# 初始化随机数生成器并尝试从子节点加载敌人数据。
func _ready() -> void:
	# 初始化随机种子。
	random_generator.randomize()
	# 调用子节点数据加载方法。
	_load_data_from_child()


# 从 EnemyTestData 子节点获取并校验 AI 配置数据。
func _load_data_from_child() -> void:
	# 检查数据源节点是否存在。
	if data_source == null:
		push_error("EnemyAI：找不到子节点 EnemyTestData")
		return
	
	# 验证数据源是否包含获取配置的方法。
	if not data_source.has_method("get_ai_config"):
		push_error("EnemyAI：EnemyTestData 缺少 get_ai_config() 方法")
		return
	
	# 调用方法获取原始配置数据。
	var raw_config = data_source.call("get_ai_config")
	
	# 校验返回的数据类型是否为字典。
	if typeof(raw_config) != TYPE_DICTIONARY:
		push_error("EnemyAI：get_ai_config() 必须返回 Dictionary")
		return
	
	# 将校验通过的数据传递给正式输入接口。
	set_enemy_data(raw_config)


# 接收并解析敌人配置数据字典，初始化 AI 的各项数据库和状态。
func set_enemy_data(enemy_config: Dictionary) -> bool:
	# 重置数据加载状态并清空所有缓存数据库。
	data_loaded = false
	action_database.clear()
	category_weights.clear()
	opening_patterns.clear()
	opening_queue.clear()
	last_action_id = ""
	
	# 初始化战斗规划的起始时间。
	planned_until_time = int(enemy_config.get("plan_start_time", 0))
	
	# 分别解析并读取行动库、类别权重和开局模式数据。
	_read_action_database(enemy_config.get("actions", {}))
	_read_category_weights(enemy_config.get("category_weights", {}))
	_read_opening_patterns(enemy_config.get("opening_patterns", []))
	
	# 校验行动库数据是否有效提取。
	if action_database.is_empty():
		push_error("EnemyAI：敌人数据中没有有效的 actions")
		return false
	
	# 校验权重数据是否有效提取。
	if category_weights.is_empty():
		push_error("EnemyAI：敌人数据中没有 category_weights")
		return false
	
	# 随机选择本场战斗的开局行动序列。
	_choose_opening_pattern()
	
	# 更新数据加载完成状态并打印日志。
	data_loaded = true
	print("EnemyAI：数据加载完成，行动数量：", action_database.size())
	return true


# 遍历并整理传入的行动数据，将其格式化后存入行动数据库。
func _read_action_database(raw_actions) -> void:
	# 校验传入数据类型是否为字典。
	if typeof(raw_actions) != TYPE_DICTIONARY:
		return
	
	# 遍历字典中的每一个原始行动数据。
	var actions: Dictionary = raw_actions
	for raw_action_id in actions.keys():
		# 获取对应的行动配置。
		var raw_action_data = actions.get(raw_action_id, {})
		
		# 跳过格式不正确的非字典数据。
		if typeof(raw_action_data) != TYPE_DICTIONARY:
			continue
		
		# 复制数据并确保 ID 字段和分类字段完整，然后存入数据库。
		var action_id: String = str(raw_action_id)
		var action_data: Dictionary = raw_action_data.duplicate(true)
		action_data["id"] = str(action_data.get("id", action_id))
		action_data["category"] = str(action_data.get("category", ""))
		action_database[action_id] = action_data


# 解析行动类别的权重配置并存入缓存，确保权重不小于 0。
func _read_category_weights(raw_weights) -> void:
	# 校验传入的权重数据是否为字典类型。
	if typeof(raw_weights) != TYPE_DICTIONARY:
		return
	
	# 遍历并提取每个类别的权重值，限制最小值为0后存入字典。
	var weights: Dictionary = raw_weights
	for raw_category in weights.keys():
		var category: String = str(raw_category)
		var weight: float = float(weights.get(raw_category, 0.0))
		category_weights[category] = maxf(weight, 0.0)


# 解析预设的开局行动序列组，转换为字符串数组格式存入缓存。
func _read_opening_patterns(raw_patterns) -> void:
	# 校验传入的开局模式数据是否为数组。
	if typeof(raw_patterns) != TYPE_ARRAY:
		return
	
	# 遍历每个模式，将内部的行动 ID 转换为字符串并存入临时数组。
	for raw_pattern in raw_patterns:
		if typeof(raw_pattern) != TYPE_ARRAY:
			continue
		
		var pattern: Array[String] = []
		for raw_action_id in raw_pattern:
			pattern.append(str(raw_action_id))
		
		# 将非空的临时数组追加到开局序列组中。
		if not pattern.is_empty():
			opening_patterns.append(pattern)


# 接收规划请求，在条件允许时触发未来行动的生成。
func on_plan_requested(required_until_time: int) -> void:
	# 检查数据是否加载完毕，未加载则给出警告并终止。
	if not data_loaded:
		push_warning("EnemyAI：收到规划请求，但敌人数据尚未加载")
		return
	
	# 判断请求的时间是否已经规划过，或者当前是否正在生成中。
	if required_until_time <= planned_until_time or is_generating:
		return
	
	# 条件满足则开始生成行动直到满足请求的时间。
	_generate_actions_until(required_until_time)


# 循环生成敌人行动直到规划时间达到要求，并将行动提交给战斗总线。
func _generate_actions_until(required_until_time: int) -> void:
	# 标记生成状态开启并初始化生成计数器。
	is_generating = true
	var generated_count: int = 0
	
	# 开启循环，在规划时间未达标时不断生成行动。
	while planned_until_time < required_until_time:
		# 校验单次请求是否超出最大生成数量限制以防死循环。
		if generated_count >= MAX_ACTIONS_PER_REQUEST:
			push_error("EnemyAI：一次规划生成了过多行动，请检查行动 time_cost")
			break
		
		# 调用方法选择下一个行动 ID 并校验其有效性。
		var action_id: String = _choose_next_action()
		if action_id.is_empty():
			push_warning("EnemyAI：没有可以生成的行动")
			break
		
		# 从数据库获取该行动的具体数据并校验。
		var action_data: Dictionary = action_database.get(action_id, {})
		if action_data.is_empty():
			push_error("EnemyAI：找不到行动数据：" + action_id)
			break
		
		# 校验该行动的时间开销参数是否合法。
		var time_cost: int = int(action_data.get("time_cost", 0))
		if time_cost <= 0:
			push_error("EnemyAI：行动 " + action_id + " 的 time_cost 必须大于 0")
			break
		
		# 计算行动的执行时间并创建对应的 TimelineAction 对象。
		var execute_time: int = planned_until_time + time_cost
		var timeline_action := _create_timeline_action(action_id, action_data, execute_time)
		if timeline_action == null:
			break
		
		# 将生成的行动通过信号提交给战斗总线。
		BattleBus.action_committed.emit(timeline_action)
		
		# 更新当前的规划时间、最后行动 ID 及生成计数。
		planned_until_time = execute_time
		last_action_id = action_id
		generated_count += 1
	
	# 结束生成状态并打印本次生成的统计日志。
	is_generating = false
	print("EnemyAI：本次生成 ", generated_count, " 个行动，规划到时间 ", planned_until_time)


# 决定下一个具体行动的 ID，优先消耗开局序列，其次使用权重随机。
func _choose_next_action() -> String:
	# 尝试从开局队列中逐个弹出行动，若验证有效则直接返回。
	while not opening_queue.is_empty():
		var opening_action_id: String = opening_queue.pop_front()
		if _is_action_valid(opening_action_id, false):
			return opening_action_id
	
	# 若开局序列为空或失效，则调用权重随机方法选择行动并返回。
	return _choose_weighted_action()


# 从配置的多个开局模式中随机抽取一个，存入当前战斗的开局队列中。
func _choose_opening_pattern() -> void:
	# 清空当前的开局队列缓存。
	opening_queue.clear()
	
	# 如果没有配置开局模式则直接返回。
	if opening_patterns.is_empty():
		return
	
	# 随机生成索引并根据索引抽取特定的开局模式。
	var selected_index: int = random_generator.randi_range(0, opening_patterns.size() - 1)
	var selected_pattern: Array = opening_patterns[selected_index]
	
	# 将抽中的模式中的所有行动 ID 依次加入开局队列并打印日志。
	for action_id in selected_pattern:
		opening_queue.append(str(action_id))
	print("EnemyAI：本场开局行动：", opening_queue)


# 根据计算后的最终权重，在所有有效行动中进行加权随机选择。
func _choose_weighted_action() -> String:
	# 初始化候选列表和总权重计数器。
	var candidates: Array[Dictionary] = []
	var total_weight: float = 0.0
	
	# 遍历所有行动，过滤掉无效行动并计算有效行动的最终权重。
	for raw_action_id in action_database.keys():
		var action_id: String = str(raw_action_id)
		if not _is_action_valid(action_id, true):
			continue
		
		# 计算选中行动的权重，跳过权重无效的项。
		var action_data: Dictionary = action_database.get(action_id, {})
		var action_weight: float = _get_action_weight(action_data)
		if action_weight <= 0.0:
			continue
		
		# 将满足条件的行动及权重记入候选列表并累加总权重。
		candidates.append({"id": action_id, "weight": action_weight})
		total_weight += action_weight
	
	# 若因防连续规则导致无可用行动，则调用无视规则的兜底方法重新选择。
	if candidates.is_empty():
		return _choose_weighted_action_without_repeat_rule()
	
	# 校验总权重是否有效以防止计算异常。
	if total_weight <= 0.0:
		return ""
	
	# 根据总权重生成一个随机阈值，遍历候选列表进行递减判断以确定最终行动。
	var roll: float = random_generator.randf() * total_weight
	for candidate: Dictionary in candidates:
		roll -= float(candidate.get("weight", 0.0))
		if roll <= 0.0:
			return str(candidate.get("id", ""))
	
	# 如果由于浮点数精度没有在循环内返回，则默认返回最后一个行动。
	return str(candidates.back().get("id", ""))


# 无视“禁止连续行动”规则的加权随机方法，用于常规随机无法找到候选项时的兜底。
func _choose_weighted_action_without_repeat_rule() -> String:
	# 初始化候选列表和总权重计数器。
	var candidates: Array[Dictionary] = []
	var total_weight: float = 0.0
	
	# 遍历所有行动并进行基础过滤（不检查重复规则），计算有效行动权重。
	for raw_action_id in action_database.keys():
		var action_id: String = str(raw_action_id)
		if not _is_action_valid(action_id, false):
			continue
		
		# 计算当前行动的权重并跳过无效权重。
		var action_data: Dictionary = action_database.get(action_id, {})
		var action_weight: float = _get_action_weight(action_data)
		if action_weight <= 0.0:
			continue
		
		# 记录候选行动和权重，累加总权重。
		candidates.append({"id": action_id, "weight": action_weight})
		total_weight += action_weight
	
	# 如果候选列表依然为空或总权重无效则返回空字符串。
	if candidates.is_empty() or total_weight <= 0.0:
		return ""
	
	# 生成随机数并遍历列表递减权重，确定并返回抽中的行动。
	var roll: float = random_generator.randf() * total_weight
	for candidate: Dictionary in candidates:
		roll -= float(candidate.get("weight", 0.0))
		if roll <= 0.0:
			return str(candidate.get("id", ""))
	
	# 提供浮点精度兜底，默认返回最后一个候选行动。
	return str(candidates.back().get("id", ""))


# 计算指定行动的最终权重（类别权重乘以内部权重）。
func _get_action_weight(action_data: Dictionary) -> float:
	# 获取该行动所属的类别标识。
	var category: String = str(action_data.get("category", ""))
	
	# 从权重配置中读取该类别的基础权重值。
	var category_weight: float = float(category_weights.get(category, 0.0))
	
	# 读取该行动数据自带的内部权重值。
	var internal_weight: float = float(action_data.get("weight", 0.0))
	
	# 将两者相乘并限制最小值为0后返回最终权重。
	return maxf(category_weight * internal_weight, 0.0)


# 校验指定行动当前是否能够合法生成，包括开关状态、时间开销及防连发规则。
func _is_action_valid(action_id: String, check_repeat_rule: bool) -> bool:
	# 尝试从数据库读取该行动的具体数据，若为空则视为无效。
	var action_data: Dictionary = action_database.get(action_id, {})
	if action_data.is_empty():
		return false
	
	# 检查行动的启用开关状态，若关闭则视为无效。
	if not bool(action_data.get("enabled", true)):
		return false
	
	# 检查行动的时间开销参数是否有效。
	if int(action_data.get("time_cost", 0)) <= 0:
		return false
	
	# 如果开启了防连发检查，验证该行动是否标记为禁止连续且为刚刚使用过的行动。
	if check_repeat_rule:
		var cannot_repeat: bool = bool(action_data.get("cannot_repeat", false))
		if cannot_repeat and action_id == last_action_id:
			return false
	
	# 全部检查通过，返回该行动有效。
	return true


# 将原始的行动字典数据封装转换为标准化的 TimelineAction 对象。
func _create_timeline_action(action_id: String, action_data: Dictionary, execute_time: int) -> TimelineAction:
	# 获取当前挂载的敌人根节点作为行动的执行者，若不存在则报错并返回空。
	var enemy_actor: Node = get_parent()
	if enemy_actor == null:
		push_error("EnemyAI：找不到敌人根节点")
		return null
	
	# 实例化一个新的 TimelineAction 对象。
	var action := TimelineAction.new()
	
	# 为行动对象赋予基础名称、执行者及阵营归属信息。
	action.action_name = str(action_data.get("name", action_id))
	action.actor = enemy_actor
	action.actor_side = TimelineAction.ActorSide.ENEMY
	
	# 配置该行动消耗的时间和预先计算好的绝对执行时间。
	action.time_cost = int(action_data.get("time_cost", 0))
	action.execute_time = execute_time
	
	# 设置行动的执行优先级，限定在 0 到 3 的合法区间内。
	action.execute_priority = clampi(int(action_data.get("execute_priority", 1)), 0, 3)
	
	# 配置非主动推进时间、可取消性及是否有主动权等战斗属性标志。
	action.advances_time = false
	action.can_be_cancelled = bool(action_data.get("can_be_cancelled", true))
	action.has_initiative = bool(action_data.get("has_initiative", false))
	
	# 将具体的行动数据、目标类型和效果类型等封装进载荷字典供后续结算器读取。
	action.payload = {
		"action_id": action_id,
		"category": str(action_data.get("category", "")),
		"effect_type": str(action_data.get("effect_type", "")),
		"target_type": str(action_data.get("target_type", "player")),
		"action_data": action_data.duplicate(true)
	}
	
	# 返回构建好的行动对象。
	return action
