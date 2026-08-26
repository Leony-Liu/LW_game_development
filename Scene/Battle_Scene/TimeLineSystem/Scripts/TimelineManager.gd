class_name TimelineManager
extends Node

# ----------------- 统一输出接口 (Signals) -----------------
signal log_message(msg: String)             # 输出日志（替代画面和动画）
signal timeline_updated(events: Array)      # 时间轴刷新，UI更新图标用
signal player_turn_started(time: int)       # 通知UI等待玩家输入

# ----------------- 内部状态 -----------------
var current_time: int = 0
var event_queue: Array[TimelineEvent] = []
var all_entities: Array[BattleEntity] = []
var player_is_idle: bool = true  # 玩家是否正在等待下达指令

# ----------------- 统一输入接口 -----------------
# 1. 注册实体并启动系统
func init_battle(entities: Array[BattleEntity]) -> void:
	all_entities = entities
	current_time = 0
	player_is_idle = true
	log_message.emit("=== 战斗开始 ===")
	_fill_ai_actions()
	_run_timeline()

# 2. 玩家提交行动指令
func submit_player_action(source: BattleEntity, target: BattleEntity, action_name: String, time_cost: int, damage: int) -> void:
	player_is_idle = false
	log_message.emit("[指令录入] 玩家计划使用 [%s], 需耗时 %d (将在时间 %d 结算)" % [action_name, time_cost, current_time + time_cost])
	
	# 构造一个伤害 Callable 传递给事件
	var effect_callable = func(): target.take_damage(damage, source.entity_name, self)
	
	var event = TimelineEvent.new(current_time + time_cost, source, target, action_name, effect_callable)
	event_queue.append(event)
	_sort_queue()
	
	timeline_updated.emit(event_queue)
	_run_timeline() # 指令下达，系统开始推演时间

# 3. 清理失效实体的事件（如死亡）
func cancel_events_for(entity: BattleEntity) -> void:
	for event in event_queue:
		if event.source == entity or event.target == entity:
			event.is_valid = false

# ----------------- 核心处理逻辑 -----------------
func _run_timeline() -> void:
	# 当玩家不处于待机状态，且队列有事件时，持续步进时间
	while not player_is_idle and not event_queue.is_empty():
		var event: TimelineEvent = event_queue.pop_front()
		
		# 推进当前时间
		if current_time != event.timestamp:
			current_time = event.timestamp
			log_message.emit("--- 时间推进至 T=%d ---" % current_time)
		
		# 验证事件有效性
		if event.is_valid and not event.source.is_dead:
			log_message.emit("[%s] 施放了 [%s] -> 目标: %s" % [event.source.entity_name, event.action_name, event.target.entity_name])
			event.effect.call() # 执行效果
			
			# 如果是玩家行动完毕，时间暂停，等待下一轮指令
			if event.source.is_player:
				player_is_idle = true
		
		_fill_ai_actions() # 每次有事件执行完，检查并补全 AI 的未来行动
	
	timeline_updated.emit(event_queue)
	
	# 如果队列跑完或者玩家行动结束，触发等待输入
	if player_is_idle:
		log_message.emit("\n>>> 系统暂停等待玩家指令 (当前时间: T=%d)" % current_time)
		player_turn_started.emit(current_time)

func _fill_ai_actions() -> void:
	for entity in all_entities:
		if entity.is_player or entity.is_dead: continue
		
		# 检查该敌人是否已经在队列中排了行动
		var has_action = false
		for e in event_queue:
			if e.source == entity and e.is_valid:
				has_action = true
				break
		
		# 如果敌人当前没有排程的行动，立刻为它生成一个
		if not has_action:
			# 获取存活的玩家
			var target = all_entities.filter(func(e): return e.is_player and not e.is_dead)
			if target.size() > 0:
				var ai_delay = 50 # 假定敌人每50点时间攻击一次
				var dmg = 10
				var effect = func(): target[0].take_damage(dmg, entity.entity_name, self)
				
				var ai_event = TimelineEvent.new(current_time + ai_delay, entity, target[0], "哥布林重击", effect)
				event_queue.append(ai_event)
				log_message.emit("[系统预知] 敌人 %s 计划在 T=%d 行动" % [entity.entity_name, ai_event.timestamp])
				
	_sort_queue()

func _sort_queue() -> void:
	event_queue.sort_custom(func(a, b): return a.timestamp < b.timestamp)
