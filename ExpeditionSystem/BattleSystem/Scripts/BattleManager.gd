class_name BattleManager
extends Node

# 核心子系统挂载
@export var timeline: Timeline
@export var entity_manager: EntityManager
@export var card_manager: CardManager
@export var battle_save_module: Node # 可选：挂载 BattleSaveModules

#region 外部与中介通信信号
signal battle_started
signal battle_ended(is_player_victory: bool)
signal input_lock_changed(is_locked: bool)
signal visual_effect_requested(visual_type: String, data: Dictionary)
#endregion

# 内部状态
var is_battle_active: bool = false
var _is_waiting_for_visual: bool = false


# 连接各个子系统的中介信号
func _ready() -> void:
	_setup_connections()

func _setup_connections() -> void:
	# 1. 监听 CardManager 信号
	if card_manager:
		card_manager.card_play_requested.connect(_on_card_play_requested)

	# 2. 监听 Timeline 信号
	if timeline:
		timeline.action_triggered.connect(_on_timeline_action_triggered)
		timeline.time_advanced.connect(_on_timeline_time_advanced)
		timeline.timeline_advancement_finished.connect(_on_timeline_advancement_finished)

	# 3. 监听 EntityManager 信号
	if entity_manager:
		entity_manager.enemy_action_generated.connect(_on_enemy_action_generated)
		entity_manager.card_buff_requested.connect(_on_entity_card_buff_requested)
		entity_manager.visual_effect_generated.connect(_on_visual_effect_generated)
		entity_manager.entity_died.connect(_on_entity_died)


#region 战斗生命周期与初始化

# 外部系统调用入口：输入卡牌实例数组、玩家实体数据与敌人ID启动战斗
func start_battle(
	external_deck: Array[CardInstance],
	external_player_data: EntityData,
	enemy_id: int
) -> void:
	if is_battle_active:
		push_warning("BattleManager: 战斗已处于激活状态！")
		return

	is_battle_active = true
	print("[BattleManager] 战斗初始化启动...")

	# 1. 转换卡牌实例：将外部持久化的 CardInstance 转换为运行时的 RuntimeCard
	var runtime_deck: Array[RuntimeCard] = _convert_deck_to_runtime(external_deck)

	# 2. 若存在存档模块，写入初始快照
	if battle_save_module and battle_save_module.has_method("save_initial_state"):
		battle_save_module.save_initial_state(runtime_deck, external_player_data, enemy_id)

	# 3. 分发数据初始化各子系统
	if entity_manager:
		entity_manager.initialize(external_player_data, enemy_id)

	if card_manager:
		card_manager.initialize(runtime_deck)

	battle_started.emit()
	_set_input_locked(false)
	print("[BattleManager] 战斗系统已激活，各子系统装配完毕")


# 将 CardInstance 数组转译为战斗内专用的 RuntimeCard 数组
func _convert_deck_to_runtime(deck: Array[CardInstance]) -> Array[RuntimeCard]:
	var runtime_deck: Array[RuntimeCard] = []
	for instance in deck:
		if not instance:
			continue
		# 利用 RuntimeCard 构造函数解析 CardData 对象或其字典属性
		var runtime_card = RuntimeCard.new(instance.card_id, instance.card_data)
		runtime_deck.append(runtime_card)
	return runtime_deck

#endregion


#region 出牌与资源仲裁流

# 响应玩家手牌出牌请求：进行资源校验与出牌调度
func _on_card_play_requested(runtime_card: RuntimeCard) -> void:
	if not is_battle_active or timeline.is_advancing:
		card_manager.cancel_play_card(runtime_card)
		return

	# 1. 资源预检：向 EntityManager 校验玩家是否能支付该卡牌消耗
	var cost = runtime_card.get_resource_cost()
	if not entity_manager.can_player_afford(cost, "stamina"):
		print("[BattleManager] 出牌被拦截：体力不足 (需要: %d)" % cost)
		card_manager.cancel_play_card(runtime_card)
		return

	# 2. 仲裁通过：扣除资源并让手牌确认离手进弃牌堆
	_set_input_locked(true)
	entity_manager.consume_player_resource(cost, "stamina")
	card_manager.confirm_play_card(runtime_card)

	# 3. 将 RuntimeCard 提交给 Timeline，转换并启动时间推进
	timeline.receive_card(runtime_card, "player", "enemy")

#endregion


#region 时间轴调度与行动结算

# 时间轴推进经过特定刻度，触发需要生效的 CombatAction
func _on_timeline_action_triggered(action: CombatAction) -> void:
	# 1. 实体数值结算：交由 EntityManager 结算护盾、生命等属性冲击与实体 Buff
	entity_manager.execute_action(action)

	# 2. 卡牌增益结算：若该行动包含对卡牌的修改，转发给 CardManager
	for card_buff in action.card_buffs:
		card_manager.apply_buff_to_all_hand_cards(card_buff)

	# 3. 动画等待与挂起机制：若触发了视觉表现，等待播放完毕后再唤醒时间轴
	if _is_waiting_for_visual:
		await _wait_for_visual_complete()

	# 4. 唤醒时间轴继续推移
	if is_battle_active:
		timeline.notify_action_finished()


# 时间轴流动过程中分段广播流逝时间：推进手牌限时 Buff
func _on_timeline_time_advanced(delta_time: int) -> void:
	if card_manager:
		card_manager.advance_hand_buffs_time(delta_time)


# 单次出牌导致的时间推移与沿途动作全部结算完成
func _on_timeline_advancement_finished() -> void:
	if is_battle_active:
		_set_input_locked(false)

#endregion


#region 子系统事件中继与转发

# 敌人 AI 决策完毕，将生成的行动压入时间轴排期
func _on_enemy_action_generated(action: CombatAction) -> void:
	if timeline:
		timeline.add_action(action)


# 实体系统产生卡牌 Buff 诉求时的路由
func _on_entity_card_buff_requested(_target_id: String, buff: CardBuff) -> void:
	if card_manager:
		card_manager.apply_buff_to_all_hand_cards(buff)


# 转发实体/卡牌系统的视觉请求给外部展示层
func _on_visual_effect_generated(visual_type: String, data: Dictionary) -> void:
	_is_waiting_for_visual = true
	visual_effect_requested.emit(visual_type, data)


# 供外部视觉控制器（如 VisualManager）在动画播放完毕后回调
func notify_visual_completed() -> void:
	_is_waiting_for_visual = false


# 实体阵亡结算
func _on_entity_died(entity: CombatEntity) -> void:
	is_battle_active = false
	_set_input_locked(true)
	
	var is_player_victory = not entity.is_player
	print("[BattleManager] 战斗结束！胜者: ", "玩家" if is_player_victory else "敌人")
	battle_ended.emit(is_player_victory)


# 控制玩家手牌交互锁
func _set_input_locked(is_locked: bool) -> void:
	input_lock_changed.emit(is_locked)
	if card_manager and card_manager.player_hand_deck and card_manager.player_hand_deck.has_method("set_input_locked"):
		card_manager.player_hand_deck.set_input_locked(is_locked)


# 内部挂起协程，等待视觉完成
func _wait_for_visual_complete() -> void:
	while _is_waiting_for_visual:
		await get_tree().process_frame

#endregion
