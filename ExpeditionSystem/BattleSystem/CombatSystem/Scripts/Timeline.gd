## 管理 Battle 的逻辑时间、行动排序与逐项完成同步。
## 外部结算必须携带原行动确认，避免旧确认唤醒其他行动。
class_name Timeline
extends Node

# 时间轴数据变化信号（供 UI/表现层更新指针位置与行动序列）
signal timeline_data_updated(current_time: int, action_line: Array[CombatAction])
# 命中行动点信号（通知 BattleManager 调派 EntityManager 结算属性并播放动画）
signal action_triggered(action: CombatAction)
# 时间推进完成信号（沿途行动已全部结算，通知 BattleManager 解除玩家输入锁定）
signal timeline_advancement_finished
# 推进的时间
signal time_advanced(delta_time: int)
# 内部协程同步信号：仅由当前行动的有效确认或取消唤醒。
signal _action_completed_step(action: CombatAction)

# 战斗时间
var current_time: int = 0
# 行动队列
var action_line: Array[CombatAction] = []
# 是否处于推进与结算状态
var is_advancing: bool = false
var _pending_action: CombatAction = null
var _advancement_cancelled: bool = false


#region 接收输入与排期

# 添加外部已打包好的行动并重新排序
func add_action(action: CombatAction) -> void:
	action_line.append(action)
	action_line.sort_custom(_sort_actions)
	timeline_data_updated.emit(current_time, action_line.duplicate())

# 接收玩家打出的卡牌，转换为 CombatAction、压入时间轴并驱动时间推进
func receive_card(runtime_card: RuntimeCard, source_id: String = "player", target_id: String = "enemy") -> void:
	var time_cost = runtime_card.get_time_cost()
	var base_priority = runtime_card.get_priority()
	var target_time = current_time + time_cost

	# 将 RuntimeCard 实例化为统一的 CombatAction
	var card_action = runtime_card.create_action(source_id, target_id, current_time)

	# 优先级为 0 则在当前时间瞬间触发；非 0 则在耗时推移后的目标时间触发
	if base_priority == 0:
		card_action.trigger_time = current_time
	else:
		card_action.trigger_time = target_time

	add_action(card_action)

	# 启动时间轴推进向目标时间流动
	advance_timeline_to(target_time)

#endregion


#region 时间推进与执行流

# 推进时间轴到目标时间，中途遇到行动则暂停并抛出结算
func advance_timeline_to(target_time: int) -> void:
	if is_advancing:
		return
	is_advancing = true
	_advancement_cancelled = false

	while not _advancement_cancelled:
		var next_action = pop_next_action_before_or_equal(target_time)

		if next_action == null:
			# 结算到目标点的最后一段剩余时间
			var delta = target_time - current_time
			if delta > 0:
				current_time = target_time
				time_advanced.emit(delta) # 扣除手牌 Buff 时间与回复体力
				timeline_data_updated.emit(current_time, action_line.duplicate())
			break

		# 推进到下一个动作点，并同步中途流逝的时间
		var delta_to_action = next_action.trigger_time - current_time
		if delta_to_action > 0:
			current_time = next_action.trigger_time
			time_advanced.emit(delta_to_action) # 扣除手牌 Buff 时间与回复体力
			timeline_data_updated.emit(current_time, action_line.duplicate())

		# 先登记待完成行动，确保同步确认不会早于等待状态。
		_pending_action = next_action
		action_triggered.emit(next_action)
		if _pending_action == next_action and not _advancement_cancelled:
			await _action_completed_step

	_pending_action = null
	is_advancing = false
	timeline_advancement_finished.emit()

# 仅接受当前行动的首次完成确认，拒绝重复或过期确认。
func notify_action_finished(action: CombatAction) -> bool:
	if action == null or action != _pending_action:
		return false
	_pending_action = null
	_action_completed_step.emit(action)
	return true


# 终止当前推进并清空未执行行动，保证 Battle 结束后协程可退出。
func cancel_advancement() -> void:
	_advancement_cancelled = true
	action_line.clear()
	var cancelled_action := _pending_action
	_pending_action = null
	if cancelled_action != null:
		_action_completed_step.emit(cancelled_action)
	timeline_data_updated.emit(current_time, action_line.duplicate())

#endregion


#region 队列查询与管理

# 用于时间轴排序的方法
func _sort_actions(a: CombatAction, b: CombatAction) -> bool:
	if a.trigger_time != b.trigger_time:
		return a.trigger_time < b.trigger_time # 时间早的优先
	if a.priority != b.priority:
		if a.priority == 0 or b.priority == 0:
			return a.priority == 0              # Priority 0 始终最先
		return a.priority < b.priority         # 数值更小的优先
	if a.is_player != b.is_player:
		return a.is_player                    # 同时间同优先级，玩家优先
	return false                              # 同阵营精确并列保留既有未定义语义

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

# 清除指定时间（含）之前的所有敌人行动
func clear_enemy_actions(target_time: int) -> void:
	# 逆序遍历安全移除
	for i in range(action_line.size() - 1, -1, -1):
		var action = action_line[i]
		# 如果不是玩家行动，且触发时间小于或等于目标时间
		if not action.is_player and action.trigger_time <= target_time:
			action_line.remove_at(i)
	timeline_data_updated.emit(current_time, action_line.duplicate())

#endregion
