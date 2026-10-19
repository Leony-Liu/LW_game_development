## 管理单场 Battle 的启动、子系统协调与结束信号。
## 只在全部启动步骤成功后进入激活状态。
class_name BattleManager
extends Node

const PLAYER_ADVANCE_TIME: int = 10
const DRAW_TO_FULL_STAMINA_COST: int = 1

enum BattleResult { NONE, VICTORY, DEFEAT }

# 核心子系统挂载
@export var timeline: Timeline
@export var entity_manager: EntityManager
@export var card_manager: CardManager
@export var battle_ui: CanvasLayer
@export var combat_hud: CombatHUD # 必需：只接收显示快照。
@export var battle_save_module: Node # 可选：挂载 BattleSaveModules
@export var wait_for_combat_presentation: bool = false

#region 外部与中介通信信号
signal battle_started
signal battle_ended(is_player_victory: bool)
signal input_lock_changed(is_locked: bool)
signal visual_effect_requested(visual_type: String, data: Dictionary)
#endregion

# 内部状态
var is_battle_active: bool = false
var battle_result: BattleResult = BattleResult.NONE
var _is_starting_battle: bool = false
var _is_waiting_for_visual: bool = false
var _internal_input_locked: bool = true
var _presentation_input_ready: bool = false
var _effective_input_locked: bool = false
var _dependencies_ready: bool = false
var _hud_refresh_queued: bool = false


# 连接各个子系统的中介信号
func _ready() -> void:
	if not _validate_dependencies():
		set_process_unhandled_input(false)
		return
	_connect_hud_updates()
	_setup_connections()
	_dependencies_ready = true
	_apply_battle_presentation()
	_apply_effective_input_lock()
	_refresh_hud()


# 通过 InputMap 动作接收战斗键盘输入，物理按键可在运行时重绑。
func _unhandled_input(event: InputEvent) -> void:
	if not is_battle_active:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("combat_draw_to_full"):
		request_draw_to_full()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("combat_advance_time"):
		request_advance_time()
		get_viewport().set_input_as_handled()


# 校验场景保存的必需子系统引用。
func _validate_dependencies() -> bool:
	if timeline == null or entity_manager == null or card_manager == null:
		push_error("BattleManager: 缺少必需的 Timeline、EntityManager 或 CardManager 引用。")
		return false
	if battle_ui == null or combat_hud == null:
		push_error("BattleManager: 缺少必需的 battle_ui 或 combat_hud 引用。")
		return false
	return entity_manager.validate_configuration() and card_manager.validate_configuration() and combat_hud.validate_configuration()


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
	entity_manager.visual_effect_generated.connect(_on_visual_effect_generated)
	entity_manager.entity_died.connect(_on_entity_died)


#region 战斗生命周期与初始化

# 外部系统调用入口：输入卡牌实例数组、玩家实体数据与敌人ID启动战斗
func start_battle(
	external_deck: Array[CardInstance],
	external_player_data: EntityData,
	enemy_id: int
) -> bool:
	if not _dependencies_ready or not _validate_dependencies():
		push_error("BattleManager: 必需依赖未完成装配，拒绝启动战斗。")
		return false
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
	battle_result = BattleResult.NONE
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
	elif battle_save_module:
		push_warning("BattleManager: 可选存档模块未提供 save_initial_state，跳过战前快照。")

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
	if not _validate_dependencies():
		return false
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
	battle_result = BattleResult.NONE
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

# 校验 Battle 当前是否允许玩家发起新操作。
func _can_accept_player_control() -> bool:
	return _dependencies_ready and is_battle_active and not _effective_input_locked and not timeline.is_advancing


# 请求补满手牌；仅在至少抽到一张牌后统一支付 1 点体力。
func request_draw_to_full() -> bool:
	if not _can_accept_player_control():
		return false
	if card_manager.hand_pile.size() >= card_manager.hand_limit:
		return false
	if not entity_manager.can_player_afford(DRAW_TO_FULL_STAMINA_COST, "stamina"):
		return false

	var drawn_count := card_manager.execute_player_draw_action()
	if drawn_count <= 0:
		return false
	entity_manager.consume_player_resource(DRAW_TO_FULL_STAMINA_COST, "stamina")
	return true


# 请求空等 10 个逻辑时间单位，并沿用 Timeline 的行动结算协议。
func request_advance_time() -> bool:
	if not _can_accept_player_control():
		return false
	_set_internal_input_locked(true)
	timeline.advance_timeline_to(timeline.current_time + PLAYER_ADVANCE_TIME)
	return true

# 响应玩家手牌出牌请求：进行资源校验与出牌调度
func _on_card_play_requested(runtime_card: RuntimeCard) -> void:
	if not _can_accept_player_control():
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


# 在现有协调器收集更新事件，HUD 不连接玩法系统。
func _connect_hud_updates() -> void:
	battle_started.connect(_on_hud_battle_started)
	battle_ended.connect(_queue_hud_refresh.unbind(1))
	input_lock_changed.connect(_queue_hud_refresh.unbind(1))
	timeline.timeline_data_updated.connect(_queue_hud_refresh.unbind(2))
	timeline.pending_action_changed.connect(_queue_hud_refresh.unbind(1))
	card_manager.deck_initialized.connect(_queue_hud_refresh.unbind(1))
	card_manager.card_drawn.connect(_queue_hud_refresh.unbind(1))
	card_manager.card_played.connect(_queue_hud_refresh.unbind(1))
	card_manager.card_discarded.connect(_queue_hud_refresh.unbind(1))
	card_manager.discard_shuffled_into_draw.connect(_queue_hud_refresh.unbind(1))
	card_manager.hand_pile_cleared.connect(_queue_hud_refresh)
	_bind_hud_entity_signals()


# 初始化完成后重新绑定当前实体，保持原有刷新时机。
func _on_hud_battle_started() -> void:
	_bind_hud_entity_signals()
	_queue_hud_refresh()


# 属性仍由实体持有，协调器仅监听变动。
func _bind_hud_entity_signals() -> void:
	var entities := entity_manager.get_enemy_entities()
	if entity_manager.player_entity != null:
		entities.append(entity_manager.player_entity)
	var callback := _queue_hud_refresh.unbind(3)
	for entity in entities:
		if entity.attribute_set != null and not entity.attribute_set.attribute_updated.is_connected(callback):
			entity.attribute_set.attribute_updated.connect(callback)


# 合并同一帧内的更新，避免读取结算中的中间状态。
func _queue_hud_refresh() -> void:
	if _hud_refresh_queued:
		return
	_hud_refresh_queued = true
	_refresh_hud.call_deferred()


# 汇总值快照并向 HUD 下发，文本与布局仍由 HUD 决定。
func _refresh_hud() -> void:
	_hud_refresh_queued = false
	var enemies: Array[Dictionary] = []
	for entity in entity_manager.get_enemy_entities():
		enemies.append(_get_entity_display_data(entity))
	combat_hud.display_state({
		"player": _get_entity_display_data(entity_manager.player_entity),
		"enemies": enemies,
		"piles": {"hand": card_manager.hand_pile.size(), "limit": card_manager.hand_limit,
			"draw": card_manager.draw_pile.size(), "discard": card_manager.discard_pile.size()},
		"current_time": timeline.current_time,
		"future_actions": timeline.get_scheduled_enemy_action_snapshots(100),
		"scheduled_actions": timeline.get_scheduled_enemy_action_snapshots(1000000),
		"input_allowed": is_battle_active and not is_battle_input_locked(),
		"is_advancing": timeline.is_advancing,
		"has_pending_action": timeline.has_pending_action(),
		"battle_ended": battle_result != BattleResult.NONE,
	})


# 复制显示所需属性；没有显式上限时沿用初始化值。
func _get_entity_display_data(entity: CombatEntity) -> Dictionary:
	if entity == null:
		return {}
	var data := {"entity_id": entity.entity_id if not entity.entity_id.is_empty() else String(entity.name),
		"name": String(entity.name)}
	var attributes := entity.attribute_set
	for attribute_name in ["hp", "stamina", "mana"]:
		var max_name: String = "max_" + attribute_name
		data[attribute_name] = attributes.get_value(attribute_name) if attributes != null else 0.0
		data[max_name] = 0.0
		if attributes != null:
			data[max_name] = attributes.get_value(max_name) if attributes.get_attribute(max_name) != null else attributes.get_initial_value(attribute_name)
	return data


#region 时间轴调度与行动结算

# 时间轴推进经过特定刻度，触发需要生效的 CombatAction
func _on_timeline_action_triggered(action: CombatAction) -> void:
	# 1. 实体数值结算：交由 EntityManager 结算护盾、生命等属性冲击与实体 Buff
	entity_manager.execute_action(action)

	# 2. 卡牌增益结算：若该行动包含对卡牌的修改，转发给 CardManager
	for card_buff in action.card_buffs:
		card_manager.apply_buff_to_all_hand_cards(card_buff)

	# 3. 未来表现控制器启用等待后，由 notify_visual_completed() 恢复。
	if _is_waiting_for_visual:
		await _wait_for_visual_complete()

	# 4. 携带原行动确认，重复或过期确认不会唤醒其他行动。
	if is_battle_active:
		timeline.notify_action_finished(action)


# 时间轴流动过程中分段广播流逝时间：推进手牌限时 Buff
func _on_timeline_time_advanced(delta_time: int) -> void:
	card_manager.advance_hand_buffs_time(delta_time)
	entity_manager.advance_player_resource_regeneration(delta_time)


# 单次出牌导致的时间推移与沿途动作全部结算完成
func _on_timeline_advancement_finished() -> void:
	if is_battle_active:
		_set_internal_input_locked(false)

#endregion


#region 子系统事件中继与转发

# 敌人 AI 决策完毕，将生成的行动压入时间轴排期
func _on_enemy_action_generated(action: CombatAction) -> void:
	timeline.add_action(action)


# 转发实体/卡牌系统的视觉请求给外部展示层
func _on_visual_effect_generated(visual_type: String, data: Dictionary) -> void:
	_is_waiting_for_visual = wait_for_combat_presentation and visual_effect_requested.has_connections()
	if wait_for_combat_presentation and not _is_waiting_for_visual:
		push_warning("BattleManager: 未连接可选战斗表现，跳过表现等待。")
	visual_effect_requested.emit(visual_type, data)


# 供外部视觉控制器（如 VisualManager）在动画播放完毕后回调
func notify_visual_completed() -> void:
	_is_waiting_for_visual = false


# 实体阵亡结算
func _on_entity_died(entity: CombatEntity) -> void:
	if not is_battle_active:
		return
	is_battle_active = false
	_presentation_input_ready = false
	_internal_input_locked = true
	_is_waiting_for_visual = false
	timeline.cancel_advancement()
	_apply_battle_presentation()
	_apply_effective_input_lock()
	
	battle_result = BattleResult.DEFEAT if entity.is_player else BattleResult.VICTORY
	var is_player_victory := battle_result == BattleResult.VICTORY
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
	card_manager.set_input_locked(should_lock)


# 内部挂起协程，等待视觉完成
func _wait_for_visual_complete() -> void:
	while _is_waiting_for_visual:
		await get_tree().process_frame

#endregion
