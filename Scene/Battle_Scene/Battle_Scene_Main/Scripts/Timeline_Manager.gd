extends Node
class_name TimelineMManager

# 对外通知信号
# 时间轴内容发生变化，UI可以监听它
signal timeline_changed(actions: Array[TimelineAction], current_time: int)
# 某个行动需要进行实际结算
signal action_resolution_requested(action: TimelineAction)
# 角色的动画和表现已全部结束。
signal action_execution_finished(action: TimelineAction)
# 一个行动完成了规则结算
signal action_resolved(action: TimelineAction)
# 一个行动被取消
signal action_cancelled(action: TimelineAction, reason: StringName)
# 游戏逻辑时间经过了一段
signal time_passed(amount: int, current_time: int)
# 游戏逻辑时间被推进
signal time_advance_started(from_time: int, to_time: int)
# 时间推进结束
signal time_advance_finished(current_time: int)
# 请求时间轴 UI 将所有图标从旧时间移动到新时间。
signal time_visual_move_requested(from_time: int, to_time: int)
# UI 的移动动画已经结束。
signal time_visual_move_finished()
# 通知敌人ai布置行动
signal enemy_plan_requested(required_until_time: int)
# UI 在收到后让对应图标停留并放大。
signal action_resolution_started(action: TimelineAction)

# 时间轴状态
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
const ENEMY_PLAN_RANGE: int = 100

# TimeLine UI 最长允许等待两秒，即使 UI 动画发生错误也不能永久锁死战斗逻辑。
const VISUAL_MOVE_TIMEOUT_MSEC: int = 2000

# 是否正在等待时间轴 UI 完成横向移动。
var _waiting_for_time_visual_move: bool = false


# 初始化并在组件就绪时绑定战斗总线的行动提交信号。
func _ready() -> void:
	# 将战斗总线的行动提交信号连接到处理方法。
	BattleBus.action_committed.connect(_on_action_required)


# 主动请求敌人补充未来行动
# 向外发送信号请求敌人AI规划未来的行动。
func request_enemy_plan() -> void:
	# 计算需要敌人规划到的目标时间并发送信号。
	var required_until_time := current_time + ENEMY_PLAN_RANGE
	enemy_plan_requested.emit(required_until_time)


# 接收行动
# 接收并处理外部提交的行动申请。
func _on_action_required(action: TimelineAction) -> void:
	# 检查收到的行动是否为空以及是否在推进时间时非法提交。
	if action == null:
		push_error("TimelineManager：收到的行动为空。")
		return

	if is_advancing and action.advances_time:
		push_warning("TimelineManager：正在推进时间，不能提交新的推进时间行动。")
		return

	# 为新行动分配唯一的序列ID。
	_assign_sequence_id(action)

	# 先手行动在当前时间立即执行，必须等其动画完成后才能继续推进时间。
	if action.has_initiative and action.advances_time:
		action.execute_time = current_time
		await _resolve_single_action(action)
		await advance_time(action.time_cost)
		return

	# 如果是普通玩家行动则根据当前时间计算绝对执行时间。
	if action.execute_time < 0:
		action.execute_time = current_time + action.time_cost

	# 拦截并拒绝执行时间处于过去的无效行动。
	if action.execute_time < current_time:
		push_warning("TimelineManager：拒绝过去时间的行动：%s" % action.action_name)
		return

	# 将行动加入时间轴，如果需要推进时间则调用推进方法。
	_add_action(action)
	if action.advances_time:
		await advance_time(action.time_cost)


# 为尚未分配序列ID的行动赋予一个唯一的递增编号。
func _assign_sequence_id(action: TimelineAction) -> void:
	# 检查如果未分配则赋予当前可用编号并递增计数器。
	if action.sequence_id >= 0:
		return
	action.sequence_id = next_sequence_id
	next_sequence_id += 1


# 将新行动加入待执行列表并重新排序。
func _add_action(action: TimelineAction) -> void:
	# 将行动追加到数组后重新排序并触发时间轴变化信号。
	pending_actions.append(action)
	_sort_pending_actions()
	_emit_timeline_changed()


# 非玩家行动排列
# 对当前所有待执行的行动进行重新排序。
func _sort_pending_actions() -> void:
	# 使用自定义的比较函数对数组进行排序。
	pending_actions.sort_custom(_is_action_before)


# 定义行动列表的排序规则以决定哪个行动优先执行。
func _is_action_before(action_a: TimelineAction, action_b: TimelineAction) -> bool:
	# 第一比较：绝对执行时间，时间越早越优先。
	if action_a.execute_time != action_b.execute_time:
		return action_a.execute_time < action_b.execute_time

	# 第二比较：行动速度，3级排在1级前面。
	if action_a.execute_priority != action_b.execute_priority:
		return action_a.execute_priority > action_b.execute_priority

	# 第三比较：同级时玩家优先。
	if action_a.actor_side != action_b.actor_side:
		return action_a.actor_side == TimelineAction.ActorSide.PLAYER

	# 第四比较：更早加入时间轴的优先。
	return action_a.sequence_id < action_b.sequence_id


# 推进时间
# 推进游戏逻辑时间并依次结算沿途的所有行动。
func advance_time(amount: int) -> void:
	# 拦截无效的时间倒退和重复的时间推进请求。
	if amount < 0:
		push_error("TimelineManager：不能倒退时间。")
		return
	if is_advancing:
		push_warning("TimelineManager：已经在推进时间。")
		return

	# 计算目标时间。
	var target_time := current_time + amount

	# 每次推进前，让敌人补充到目标时间后 100 点。
	var required_until_time := target_time + ENEMY_PLAN_RANGE
	enemy_plan_requested.emit(required_until_time)

	# 标记推进状态并发送时间开始推进的信号。
	is_advancing = true
	time_advance_started.emit(current_time, target_time)

	while true:
		# 排序并寻找目标时间内最近的下一个事件时间。
		_sort_pending_actions()
		var next_event_time := _find_next_event_time(target_time)
		if next_event_time == -1:
			break

		# 先等待所有 UI 图标移动到新位置。
		await _move_time_to(next_event_time)

		# 图标移动完成后，才开始依次播放动作。
		await _resolve_actions_at_current_time()

	# 所有中途行动结束后，移动到玩家最终推进时间。
	await _move_time_to(target_time)

	# 重置当前行动与推进状态并发送时间推进结束的信号。
	current_action = null
	is_advancing = false
	_emit_timeline_changed()
	time_advance_finished.emit(current_time)


# 查找目标时间范围内最近的一个有效行动的发生时间。
func _find_next_event_time(target_time: int) -> int:
	# 遍历待执行列表返回第一个未被取消且时间在目标范围内的行动时间。
	for action in pending_actions:
		if action.is_cancelled:
			continue
		if action.execute_time <= target_time:
			return action.execute_time
	return -1


# 将逻辑时间更新到指定的新时间并处理UI动画等待。
func _move_time_to(new_time: int) -> void:
	# 目标时间小于等于当前时间时直接返回不作处理。
	if new_time <= current_time:
		return

	var old_time := current_time
	var elapsed_time := new_time - old_time

	# 若有连接UI移动信号则发送请求并进入超时等待循环。
	var visual_connections := get_signal_connection_list(&"time_visual_move_requested")
	if not visual_connections.is_empty():
		_waiting_for_time_visual_move = true
		time_visual_move_requested.emit(old_time, new_time)
		var timeout_at := Time.get_ticks_msec() + VISUAL_MOVE_TIMEOUT_MSEC

		while _waiting_for_time_visual_move:
			if Time.get_ticks_msec() >= timeout_at:
				push_error("TimelineManager：等待 TimeLine 移动动画超时。将跳过视觉等待并继续战斗。")
				_waiting_for_time_visual_move = false
				break
			await get_tree().process_frame

	# UI 动画完成或等待超时后，正式更新逻辑时间。
	current_time = new_time
	time_passed.emit(elapsed_time, current_time)
	_emit_timeline_changed()


# 供UI在横向移动动画结束后调用以解除时间轴逻辑的等待状态。
func finish_time_visual_move() -> void:
	# 检查如果正在等待则解除等待状态并发送动画结束信号。
	if not _waiting_for_time_visual_move:
		return
	_waiting_for_time_visual_move = false
	time_visual_move_finished.emit()


# 处理同一时间的行动
# 循环获取并结算当前时间点上的所有待执行行动。
func _resolve_actions_at_current_time() -> void:
	var resolved_count := 0

	while true:
		# 获取当前时间的所有行动并按优先级排序。
		var actions_now := _get_actions_at_time(current_time)
		if actions_now.is_empty():
			break
		actions_now.sort_custom(_is_action_before)

		# 过滤已取消的行动并调用单个行动结算方法。
		for action: TimelineAction in actions_now:
			if action.is_cancelled:
				pending_actions.erase(action)
				continue

			# _resolve_single_action() 内部会先通知 UI，再将行动从 pending_actions 中移除。
			await _resolve_single_action(action)

			# 累加结算次数并检查是否超出最大限制以防止无限循环。
			resolved_count += 1
			if resolved_count >= MAX_ACTIONS_PER_TIME:
				push_error("TimelineManager：同一时间触发的行动过多，可能存在无限生成行动。")
				return

	_emit_timeline_changed()


# 筛选并返回发生于指定时间点的所有行动。
func _get_actions_at_time(target_time: int) -> Array[TimelineAction]:
	var result: Array[TimelineAction] = []
	# 遍历列表并将匹配指定时间的行动存入结果数组返回。
	for action in pending_actions:
		if action.execute_time == target_time:
			result.append(action)
	return result


# 结算单个行动
# 处理单个行动的具体结算流程包括验证、通知UI和等待动画。
func _resolve_single_action(action: TimelineAction) -> void:
	current_action = action
	_current_action_execution_finished = false

	# 检查行动合法性，如果不合法则予以取消并退出。
	if not _is_action_valid(action):
		_cancel_action(action, &"action_invalid")
		current_action = null
		return

	# 先通知 UI：对应图标现在应固定在左端并保持放大。
	action_resolution_started.emit(action)

	# UI 已经记住这个行动后，再从待执行列表移除。
	pending_actions.erase(action)
	_emit_timeline_changed()

	# 发送实际效果结算请求并等待动作表现结束。
	action_resolution_requested.emit(action)
	while not _current_action_execution_finished:
		await action_execution_finished

	# 动画结束后发送行动已结算信号并清理状态。
	action_resolved.emit(action)
	_current_action_execution_finished = false
	current_action = null


# 供外部管理器在角色动作表现结束时调用以继续时间轴。
func finish_action_execution(action: TimelineAction) -> void:
	# 校验当前是否正在结算传入的行动。
	if current_action == null:
		push_warning("TimelineManager：当前没有正在结算的行动。")
		return
	if current_action != action:
		push_warning("TimelineManager：收到的完成行动与当前行动不一致。")
		return

	# 校验通过则标记完成并发送信号。
	if _current_action_execution_finished:
		return
	_current_action_execution_finished = true
	action_execution_finished.emit(action)


# 检查特定行动当前是否仍然合法且可被执行。
func _is_action_valid(action: TimelineAction) -> bool:
	# 校验行动是否被取消或行动发起者是否无效。
	if action.is_cancelled:
		return false
	if action.actor == null:
		return false
	if not is_instance_valid(action.actor):
		return false

	# 后续玩家或敌人可以添加这个方法，用来判断自己是否处于破韧、死亡或禁止行动状态。
	if action.actor.has_method("can_resolve_timeline_action"):
		return action.actor.can_resolve_timeline_action(action)

	return true


# 取消行动
# 批量取消指定角色在特定时间段内的所有可取消行动。
func cancel_actions_for_actor(actor: Node, from_time: int, until_time: int, reason: StringName) -> void:
	var actions_copy := pending_actions.duplicate()

	# 遍历复制的行动列表，筛选符合角色、可取消条件及时间范围的行动进行取消。
	for action: TimelineAction in actions_copy:
		if action.actor != actor:
			continue
		if not action.can_be_cancelled:
			continue
		# 使用 [from_time, until_time)，包含开始时间，不包含结束时间。
		if action.execute_time >= from_time and action.execute_time < until_time:
			_cancel_action(action, reason)

	_emit_timeline_changed()


# 执行单个行动的取消逻辑并将其移出待执行列表。
func _cancel_action(action: TimelineAction, reason: StringName) -> void:
	# 检查行动可否取消。
	if action.is_cancelled:
		return
	if not action.can_be_cancelled:
		return

	# 调用行动自身取消方法后从列表中移除并发送信号。
	action.cancel(reason)
	pending_actions.erase(action)
	action_cancelled.emit(action, reason)


# 提供UI读取方法
# 获取当前时间到指定可见范围内的所有有效行动列表。
func get_visible_actions(visible_range: int = 100) -> Array[TimelineAction]:
	var result: Array[TimelineAction] = []
	var end_time := current_time + visible_range

	# 遍历并筛选处于指定时间范围内且未取消的行动进行排序返回。
	for action in pending_actions:
		if action.is_cancelled:
			continue
		if action.execute_time >= current_time and action.execute_time <= end_time:
			result.append(action)

	result.sort_custom(_is_action_before)
	return result


# 向外广播当前时间轴待执行行动列表发生变化的信号。
func _emit_timeline_changed() -> void:
	# 复制当前的待执行行动列表连同当前时间一起通过信号发送出去。
	timeline_changed.emit(pending_actions.duplicate(), current_time)
