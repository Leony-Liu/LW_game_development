class_name CombatManager
extends Node

# 下级脚本
@export var timeline: Timeline
@export var enemy_ai: EnemyAI
@export var processor: CombatProcessor

# 提供画面变化信号
signal input_lock_state_changed(is_locked: bool)
# 时间轴数据有变化
signal timeline_data_updated(current_time: int, action_queue: Array)
# 通知外部播放动画
signal request_visual_effect(effect_data: Dictionary) 

# 外部输入信号 (由Manager内部等待或连接)
## TODO 注意：这两个信号可以由外部直接连接到Manager的内部回调上
# 外部连接：UI系统发出的出牌信号 -> _card_played
# 外部连接：动画系统发出的完成信号 -> _visual_finished

var _is_waiting_visual: bool = false
var _is_input_locked: bool = false

# 系统初始化，连接信号
func _ready():
	# 有动画生成
	processor.visual_effect_generated.connect(_on_processor_visual_generated)
	
	# 系统启动，初始化敌人行动
	enemy_ai.plan_actions(timeline)
	timeline_data_updated.emit(timeline.current_time, timeline.action_queue.duplicate())

# TODO （等待信号输入）系统入口，玩家出牌后触发
func _card_played(card_cost: int, action_name: String, effect_data: Dictionary, priority: int = 1):
	if _is_input_locked:
		return
		
	_set_input_lock(true)
	
	# 1. 封装并注入玩家行动
	var target_time = timeline.current_time + card_cost
	var player_action = CombatAction.new()
	player_action.is_player = true
	player_action.action_name = action_name
	player_action.trigger_time = target_time
	player_action.priority = priority
	player_action.effect_data = effect_data
	
	timeline.add_action(player_action)
	
	# 2. 启动核心逻辑流
	_advance_timeline_logic(target_time)

# 动画进程结束
func _visual_finished():
	_is_waiting_visual = false

# 推进时间
func _advance_timeline_logic(target_time: int):
	while true:
		var next_action = timeline.pop_next_action_before_or_equal(target_time)
		
		if next_action == null:
			# 路径上无行动，直接跳跃到目标时间
			timeline.current_time = target_time
			break
			
		# 推进到动作时间点
		timeline.current_time = next_action.trigger_time
		timeline_data_updated.emit(timeline.current_time, timeline.action_queue.duplicate())
		
		# 处理器执行纯逻辑，并会通过信号吐出视觉需求
		processor.execute_logic(next_action)
		
		# 如果处理器产生了视觉表现请求，则挂起系统，等待外部视觉系统完成
		if _is_waiting_visual:
			await self._wait_for_visual() 
			
	# 一次玩家出牌推进完全结束，AI填补空缺
	enemy_ai.plan_actions(timeline)
	timeline_data_updated.emit(timeline.current_time, timeline.action_queue.duplicate())
	_set_input_lock(false)

# 等待外部动画完成的内部协程封装
func _wait_for_visual():
	while _is_waiting_visual:
		await get_tree().process_frame

# 需要推进视觉内容
func _on_processor_visual_generated(effect_data: Dictionary):
	_is_waiting_visual = true
	# 将下级的视觉请求转发给外部系统
	request_visual_effect.emit(effect_data)

# 玩家输入状态锁定
func _set_input_lock(locked: bool):
	_is_input_locked = locked
	input_lock_state_changed.emit(_is_input_locked)
