class_name CombatManager
extends Node

# 下级脚本
@export var timeline: Timeline
@export var enemy_ai: EnemyAI
@export var processor: ProcessorManager

# 提供画面变化信号
signal input_lock_state_changed(is_locked: bool)
# 时间轴数据有变化
signal timeline_data_updated(current_time: int, action_line: Array)
# 通知外部播放动画
signal request_visual_effect(effect_data: Dictionary) 

var _is_waiting_visual: bool = false
var _is_input_locked: bool = false

# 系统初始化，连接信号
func _ready():
	# 有动画生成
	processor.visual_effect_generated.connect(_on_processor_visual_generated)

# 接收实体数据并下发 
func initialize_combat(player_data: EntityData, enemy_data: EnemyData) -> void:
	# 1. 唤醒并初始化 AI 的动作池与冷却器
	enemy_ai.initialize(enemy_data)
	
	# 2. 将数据透传给处理器进行底层实例化[cite: 5]
	if processor.has_method("initialize_entities"):
		processor.initialize_entities(player_data, enemy_data)
		
	# 3. 实体准备完毕后，初始化敌人行动并刷新时间轴[cite: 5]
	enemy_ai.plan_actions(timeline)
	timeline_data_updated.emit(timeline.current_time, timeline.action_line.duplicate())

# 系统入口，玩家出牌后触发
func runtimecard_to_combataction(runtime_card: RuntimeCard) -> void:
	if _is_input_locked:
		return
		
	_set_input_lock(true)
	
	# 解析卡牌数据
	var resource_cost = runtime_card.get_resource_cost()
	var time_cost = runtime_card.get_time_cost()
	var action_name = runtime_card.get_action_name()
	var effect_data = runtime_card.compile_effect_data()
	var base_priority = runtime_card.get_priority()
	
	var target_time = timeline.current_time + time_cost
	
	# 1. 封装并注入扣除资源行动
	var cost_action = CombatAction.new()
	cost_action.is_player = true
	cost_action.action_name = "消耗资源"
	cost_action.trigger_time = timeline.current_time
	cost_action.priority = base_priority + 10 # 拔高优先级，确保在同时间的其余行动前结算
	cost_action.effect_data = {"type": "pay_cost", "amount": resource_cost}
	timeline.add_action(cost_action)
	
	# 2. 封装并注入卡牌实际效果行动
	var effect_action = CombatAction.new()
	effect_action.is_player = true
	effect_action.action_name = action_name
	
	# 3.判断优先级决定触发时机
	if base_priority == 0:
		# 优先级为0：立刻在当前时间点触发
		effect_action.trigger_time = timeline.current_time
	else:
		# 优先级非0：在推进后的目标时间触发
		effect_action.trigger_time = target_time

	effect_action.priority = base_priority
	effect_action.effect_data = effect_data
	timeline.add_action(effect_action)
	
	# 4. 启动核心逻辑流，向着目标时间推进
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
		timeline_data_updated.emit(timeline.current_time, timeline.action_line.duplicate())
		
		# 处理器执行纯逻辑，并会通过信号吐出视觉需求
		processor.accept_action(next_action)
		
		# 如果处理器产生了视觉表现请求，则挂起系统，等待外部视觉系统完成
		if _is_waiting_visual:
			await self._wait_for_visual() 
			
	# 一次玩家出牌推进完全结束，AI填补空缺
	enemy_ai.plan_actions(timeline)
	timeline_data_updated.emit(timeline.current_time, timeline.action_line.duplicate())
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
