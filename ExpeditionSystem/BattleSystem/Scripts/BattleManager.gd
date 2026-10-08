## 管理单场 Battle 的启动、子系统协调与结束信号。
## 只在全部启动步骤成功后进入激活状态。
class_name BattleManager
extends Node

# 核心子系统挂载
@export var timeline: Timeline
@export var entity_manager: EntityManager
@export var card_manager: CardManager
@export var battle_ui: CanvasLayer
@export var battle_save_module: Node # 可选：挂载 BattleSaveModules

#region 外部与中介通信信号
signal battle_started
signal battle_ended(is_player_victory: bool)
signal input_lock_changed(is_locked: bool)
signal visual_effect_requested(visual_type: String, data: Dictionary)
#endregion

# 内部状态
var is_battle_active: bool = false
var _is_starting_battle: bool = false
var _is_waiting_for_visual: bool = false
var _internal_input_locked: bool = true
var _presentation_input_ready: bool = false
var _effective_input_locked: bool = false


# 连接各个子系统的中介信号
func _ready() -> void:
	_validate_dependencies()
	_setup_connections()
	_apply_battle_presentation()
	_apply_effective_input_lock()


# 校验场景保存的必需子系统引用。
func _validate_dependencies() -> void:
	assert(timeline != null, "BattleManager: 缺少必需的 timeline 引用。")
	assert(entity_manager != null, "BattleManager: 缺少必需的 entity_manager 引用。")
	assert(card_manager != null, "BattleManager: 缺少必需的 card_manager 引用。")
	assert(battle_ui != null, "BattleManager: 缺少必需的 battle_ui 引用。")
	assert(card_manager.player_hand_deck is PlayerHandDeck, "BattleManager: card_manager 缺少必需的 PlayerHandDeck 引用。")


# 连接 Card、Timeline 与 Entity 子系统信号。
func _setup_connections() -> void:
	# 1. 监听 CardManager 信号
	card_manager.card_play_requested.connect(_on_card_play_requested)

	# 2. 监听 Timeline 信号
	timeline.action_triggered.connect(_on_timeline_action_triggered)
	timeline.time_advanced.connect(_on_timeline_time_advanced)
	timeline.timeline_advancement_finished.connect(_on_timeline_advancement_finished)

	# 3. 监听 EntityManager 信号
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
) -> bool:
	if is_battle_active:
		push_warning("BattleManager: 战斗已处于激活状态！")
		return false
	if _is_starting_battle:
		push_warning("BattleManager: 战斗启动已在处理中！")
		return false
	if not _validate_startup_inputs(external_deck, external_player_data, enemy_id):
		_secure_failed_startup_state()
		return false

	# 转换本身不修改 Battle 子系统状态。
	var runtime_deck: Array[RuntimeCard] = _convert_deck_to_runtime(external_deck)
	if not entity_manager.can_initialize(external_player_data, enemy_id):
		_secure_failed_startup_state()
		return false
	if not card_manager.can_initialize(runtime_deck):
		_secure_failed_startup_state()
		return false

	_is_starting_battle = true
	_presentation_input_ready = false
	_internal_input_locked = true
	_apply_battle_presentation()
	_apply_effective_input_lock()
	print("[BattleManager] 战斗初始化启动...")

	# 所有可恢复校验已通过，再按实体、卡牌顺序写入状态。
	if not entity_manager.initialize(external_player_data, enemy_id):
		push_error("BattleManager: EntityManager 初始化失败。")
		_secure_failed_startup_state()
		return false
	if not card_manager.initialize(runtime_deck):
		push_error("BattleManager: CardManager 初始化失败。")
		_secure_failed_startup_state()
		return false

	# 3. 若存在存档模块，在成功装配后写入初始快照。
	if battle_save_module and battle_save_module.has_method("save_initial_state"):
		battle_save_module.save_initial_state(runtime_deck, external_player_data, enemy_id)

	is_battle_active = true
	_is_starting_battle = false
	_internal_input_locked = false
	_apply_battle_presentation()
	_apply_effective_input_lock()
	battle_started.emit()
	print("[BattleManager] 战斗系统已激活，各子系统装配完毕")
	return true


# 接收远征层的表现就绪门闩，不覆盖时间轴等战斗内部锁。
func set_presentation_ready(is_ready: bool) -> bool:
	if is_ready and not is_battle_active:
		push_error("BattleManager: Battle 未激活，不能开放战斗表现与输入。")
		return false
	_presentation_input_ready = is_ready
	_apply_battle_presentation()
	_apply_effective_input_lock()
	return true


# 返回远征层是否已允许战斗表现。
func is_presentation_ready() -> bool:
	return _presentation_input_ready


# 返回合并内部锁与表现门闩后的最终输入状态。
func is_battle_input_locked() -> bool:
	return _effective_input_locked


# 在修改任何 Battle 状态前校验启动输入与必需引用。
func _validate_startup_inputs(
	external_deck: Array[CardInstance],
	external_player_data: EntityData,
	enemy_id: int
) -> bool:
	if timeline == null or entity_manager == null or card_manager == null:
		push_error("BattleManager: 启动所需子系统引用不完整。")
		return false
	if card_manager.player_hand_deck == null:
		push_error("BattleManager: 缺少必需的 PlayerHandDeck 引用。")
		return false
	if external_player_data == null:
		push_error("BattleManager: external_player_data 为空。")
		return false
	if enemy_id < 0:
		push_error("BattleManager: enemy_id 无效。")
		return false
	for card_instance in external_deck:
		if card_instance == null or card_instance.card_data == null:
			push_error("BattleManager: external_deck 包含无效 CardInstance。")
			return false
	return true


# 将失败后的 Battle 保持为未激活、隐藏且锁定状态。
func _secure_failed_startup_state() -> void:
	_is_starting_battle = false
	is_battle_active = false
	_presentation_input_ready = false
	_internal_input_locked = true
	_apply_battle_presentation()
	_apply_effective_input_lock()


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
	if not is_battle_active or _effective_input_locked or timeline.is_advancing:
		card_manager.cancel_play_card(runtime_card)
		return

	# 1. 资源预检：向 EntityManager 校验玩家是否能支付该卡牌消耗
	var cost = runtime_card.get_resource_cost()
	if not entity_manager.can_player_afford(cost, "stamina"):
		print("[BattleManager] 出牌被拦截：体力不足 (需要: %d)" % cost)
		card_manager.cancel_play_card(runtime_card)
		return

	# 2. 仲裁通过：扣除资源并让手牌确认离手进弃牌堆
	_set_internal_input_locked(true)
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
	card_manager.advance_hand_buffs_time(delta_time)


# 单次出牌导致的时间推移与沿途动作全部结算完成
func _on_timeline_advancement_finished() -> void:
	if is_battle_active:
		_set_internal_input_locked(false)

#endregion


#region 子系统事件中继与转发

# 敌人 AI 决策完毕，将生成的行动压入时间轴排期
func _on_enemy_action_generated(action: CombatAction) -> void:
	timeline.add_action(action)


# 实体系统产生卡牌 Buff 诉求时的路由
func _on_entity_card_buff_requested(_target_id: String, buff: CardBuff) -> void:
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
	_presentation_input_ready = false
	_internal_input_locked = true
	_apply_battle_presentation()
	_apply_effective_input_lock()
	
	var is_player_victory = not entity.is_player
	print("[BattleManager] 战斗结束！胜者: ", "玩家" if is_player_victory else "敌人")
	battle_ended.emit(is_player_victory)


# 更新 Battle 内部交互锁，并与远征表现门闩合并。
func _set_internal_input_locked(is_locked: bool) -> void:
	_internal_input_locked = is_locked
	_apply_effective_input_lock()


# 显隐战斗 UI，BattleSystem 本身保持运行。
func _apply_battle_presentation() -> void:
	battle_ui.visible = is_battle_active and _presentation_input_ready


# 仅在最终锁状态变化时向手牌广播。
func _apply_effective_input_lock() -> void:
	var should_lock := (
		not is_battle_active
		or _internal_input_locked
		or not _presentation_input_ready
	)
	if should_lock == _effective_input_locked:
		return
	_effective_input_locked = should_lock
	input_lock_changed.emit(should_lock)
	var hand_deck := card_manager.player_hand_deck as PlayerHandDeck
	hand_deck.set_input_locked(should_lock)


# 内部挂起协程，等待视觉完成
func _wait_for_visual_complete() -> void:
	while _is_waiting_for_visual:
		await get_tree().process_frame

#endregion
