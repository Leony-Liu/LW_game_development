extends Node
class_name ActionTimelineManager


# —————— 对外通知信号 ——————

# 时间轴内容发生变化，UI可以监听它
signal timeline_changed(actions: Array[TimelineAction],current_time: int)
# 某个行动需要进行实际结算
signal action_resolution_requested(action: TimelineAction)
# 角色的动画和表现已全部结束。
signal action_execution_finished(action: TimelineAction)
# 一个行动完成了规则结算
signal action_resolved(action: TimelineAction)
# 一个行动被取消
signal action_cancelled(action: TimelineAction,reason: StringName)
# 游戏逻辑时间经过了一段
signal time_passed(amount: int,current_time: int)
# 游戏逻辑时间被推进
signal time_advance_started(from_time: int,to_time: int)
# 时间推进结束
signal time_advance_finished(current_time: int)
# 通知敌人ai布置行动
signal enemy_plan_requested(required_until_time:int)

# —————— 时间轴状态 ——————

# 当前游戏逻辑时间
var current_time: int = 0
# 尚未执行的所有行动
var pending_actions: Array[TimelineAction] = []
# 当前正在结算的行动
var current_action: TimelineAction = null
# 当前行动的动画或表现是否已经完成。
var _current_action_execution_finished: bool = false
# 当前是否正在推进时间
var is_advancing: bool = false
# 用来给行动分配唯一编号
var next_sequence_id: int = 1
# 防止同一个时间点意外生成无限行动
const MAX_ACTIONS_PER_TIME: int = 100

# 敌人提前布置行动的范围
const ENEMY_PLAN_RANGE : int = 100


# 程序入口
func _ready() -> void:
	BattleBus.action_committed.connect(_on_action_required)

# —————— 主动请求敌人补充未来行动 ——————

func request_enemy_plan() -> void:
	var required_until_time := current_time + ENEMY_PLAN_RANGE
	enemy_plan_requested.emit(required_until_time)

# —————— 接收行动 ——————

# 处理行动申请
func _on_action_required(action: TimelineAction) -> void:
	if action == null:
		push_error("ActionTimelineManager：收到的行动为空。")
		return

	if is_advancing and action.advances_time:
		push_warning(
			"ActionTimelineManager：正在推进时间，"
			+ "不能提交新的推进时间行动。"
		)
		return

	_assign_sequence_id(action)

	# 先手行动在当前时间立即执行。
	# 必须等其动画完成后，才能继续推进时间。
	if action.has_initiative and action.advances_time:
		action.execute_time = current_time

		await _resolve_single_action(action)
		await advance_time(action.time_cost)
		return

	# 普通玩家行动使用相对时间。
	if action.execute_time < 0:
		action.execute_time = current_time + action.time_cost

	# 不接受位于过去的行动。
	if action.execute_time < current_time:
		push_warning(
			"ActionTimelineManager：拒绝过去时间的行动：%s"
			% action.action_name
		)
		return

	_add_action(action)

	if action.advances_time:
		await advance_time(action.time_cost)


func _assign_sequence_id(action: TimelineAction) -> void:
	if action.sequence_id >= 0:
		return

	action.sequence_id = next_sequence_id
	next_sequence_id += 1


func _add_action(action: TimelineAction) -> void:
	pending_actions.append(action)
	_sort_pending_actions()
	_emit_timeline_changed()


# —————— 非玩家行动排列 ——————

func _sort_pending_actions() -> void:
	pending_actions.sort_custom(_is_action_before)


func _is_action_before(
	action_a: TimelineAction,
	action_b: TimelineAction
) -> bool:
	# 第一比较：绝对执行时间
	if action_a.execute_time != action_b.execute_time:
		return action_a.execute_time < action_b.execute_time

	# 第二比较：行动速度，3级排在1级前面
	if action_a.execute_priority != action_b.execute_priority:
		return action_a.execute_priority > action_b.execute_priority

	# 第三比较：同级时玩家优先
	if action_a.actor_side != action_b.actor_side:
		return (
			action_a.actor_side
			== TimelineAction.ActorSide.PLAYER
		)

	# 第四比较：更早加入时间轴的优先
	return action_a.sequence_id < action_b.sequence_id


# —————— 推进时间 ——————

func advance_time(amount: int) -> void:
	if amount < 0:
		push_error("ActionTimelineManager：不能倒退时间。")
		return

	if is_advancing:
		push_warning("ActionTimelineManager：已经在推进时间。")
		return

	var target_time := current_time + amount

	# 每次推进前，让敌人补充到目标时间后 100 点。
	var required_until_time := target_time + ENEMY_PLAN_RANGE
	enemy_plan_requested.emit(required_until_time)

	is_advancing = true
	time_advance_started.emit(current_time, target_time)

	while true:
		_sort_pending_actions()

		var next_event_time := _find_next_event_time(
			target_time
		)

		if next_event_time == -1:
			break

		_move_time_to(next_event_time)

		# 等当前时间点的所有行动依次播放完。
		await _resolve_actions_at_current_time()

	_move_time_to(target_time)

	current_action = null
	is_advancing = false

	_emit_timeline_changed()
	time_advance_finished.emit(current_time)


# 找出目标时间以内最近的一次行动
func _find_next_event_time(target_time: int) -> int:
	for action in pending_actions:
		if action.is_cancelled:
			continue

		if action.execute_time <= target_time:
			return action.execute_time

	return -1


# 将逻辑时间移动到某个绝对时间
func _move_time_to(new_time: int) -> void:
	if new_time <= current_time:
		return

	var elapsed_time := new_time - current_time
	current_time = new_time

	# 资源恢复、Buff、道具冷却等监听该信号。
	time_passed.emit(
		elapsed_time,
		current_time
	)

	# 当前时间改变后立即刷新开发者界面。
	_emit_timeline_changed()


# —————— 处理同一时间的行动 ——————

func _resolve_actions_at_current_time() -> void:
	var resolved_count := 0

	# 使用 while，允许一个行动在结算期间
	# 添加同一时间点的新行动。
	while true:
		var actions_now := _get_actions_at_time(
			current_time
		)

		if actions_now.is_empty():
			break

		actions_now.sort_custom(_is_action_before)

		for action in actions_now:
			if action.is_cancelled:
				pending_actions.erase(action)
				continue

			pending_actions.erase(action)

			# 从待结算列表移除后立即刷新 UI。
			_emit_timeline_changed()

			# 关键：必须等待该行动的动画或表现完成。
			await _resolve_single_action(action)

			resolved_count += 1

			if resolved_count >= MAX_ACTIONS_PER_TIME:
				push_error(
					"ActionTimelineManager："
					+ "同一时间触发的行动过多，"
					+ "可能存在无限生成行动。"
				)
				return

	_emit_timeline_changed()


func _get_actions_at_time(
	target_time: int
) -> Array[TimelineAction]:
	var result: Array[TimelineAction] = []

	for action in pending_actions:
		if action.execute_time == target_time:
			result.append(action)

	return result


# —————— 结算单个行动 ———————

func _resolve_single_action(
	action: TimelineAction
) -> void:
	current_action = action
	_current_action_execution_finished = false

	if not _is_action_valid(action):
		_cancel_action(
			action,
			&"action_invalid"
		)

		current_action = null
		return

	# BattleGameManager 收到后会让对应角色执行动作。
	action_resolution_requested.emit(action)

	# 技能、Buff 等无动画行动可能在 emit 期间同步完成。
	# 只有尚未完成时才进入等待。
	while not _current_action_execution_finished:
		await action_execution_finished

	action_resolved.emit(action)

	_current_action_execution_finished = false
	current_action = null

# 由 BattleGameManager 在角色动作结束时调用。
func finish_action_execution(
	action: TimelineAction
) -> void:
	if current_action == null:
		push_warning(
			"ActionTimelineManager："
			+ "当前没有正在结算的行动。"
		)
		return

	if current_action != action:
		push_warning(
			"ActionTimelineManager："
			+ "收到的完成行动与当前行动不一致。"
		)
		return

	if _current_action_execution_finished:
		return

	_current_action_execution_finished = true
	action_execution_finished.emit(action)

func _is_action_valid(action: TimelineAction) -> bool:
	if action.is_cancelled:
		return false

	if action.actor == null:
		return false

	if not is_instance_valid(action.actor):
		return false

	# 后续玩家或敌人可以添加这个方法，
	# 用来判断自己是否处于破韧、死亡或禁止行动状态
	if action.actor.has_method("can_resolve_timeline_action"):
		return action.actor.can_resolve_timeline_action(action)

	return true


# ——————— 取消行动 ——————

func cancel_actions_for_actor(
	actor: Node,
	from_time: int,
	until_time: int,
	reason: StringName
) -> void:
	var actions_copy := pending_actions.duplicate()

	for action: TimelineAction in actions_copy:
		if action.actor != actor:
			continue

		if not action.can_be_cancelled:
			continue

		# 使用 [from_time, until_time)
		# 包含开始时间，不包含结束时间
		if (
			action.execute_time >= from_time
			and action.execute_time < until_time
		):
			_cancel_action(action, reason)

	_emit_timeline_changed()


func _cancel_action(action: TimelineAction,reason: StringName) -> void:
	if action.is_cancelled:
		return

	if not action.can_be_cancelled:
		return

	action.cancel(reason)
	pending_actions.erase(action)

	action_cancelled.emit(action, reason)


# —————— 提供UI读取方法 ———————

func get_visible_actions(visible_range: int = 100) -> Array[TimelineAction]:
	var result: Array[TimelineAction] = []
	var end_time := current_time + visible_range

	for action in pending_actions:
		if action.is_cancelled:
			continue

		if (
			action.execute_time >= current_time
			and action.execute_time <= end_time
		):
			result.append(action)

	result.sort_custom(_is_action_before)
	return result

func _emit_timeline_changed() -> void:
	timeline_changed.emit(
		pending_actions.duplicate(),
		current_time
	)
