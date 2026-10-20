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

@export_category("Combat Timing")
@export_range(0.0, 1.0, 0.01) var action_transition_delay: float = 0.1

#region 外部与中介通信信号
signal battle_started
signal battle_ended(is_player_victory: bool)
signal input_lock_changed(is_locked: bool)
signal visual_effect_requested(visual_type: String, data: Dictionary)
signal enemy_attack_started(source_id: String, execution_id: int, effect_id: int)
signal health_damage_applied(target_id: String, source_id: String, amount: float, execution_id: int, effect_id: int)
signal action_presentation_cancelled(execution_id: int)
#endregion

# 内部状态
var is_battle_active: bool = false
var battle_result: BattleResult = BattleResult.NONE
var _is_starting_battle: bool = false
var _internal_input_locked: bool = true
var _presentation_input_ready: bool = false
var _effective_input_locked: bool = false
var _dependencies_ready: bool = false
var _hud_refresh_queued: bool = false
var _enemy_action_schedule_succeeded: bool = false
var _last_replenished_enemy_action: CombatAction = null
var _next_execution_id: int = 0
var _active_execution_id: int = 0
var _active_action: CombatAction = null
var _transition_wait_execution_id: int = 0
var _next_effect_id: int = 0
var _pending_presentation_effects: Dictionary = {}
var _presentation_dispatch_open: bool = false
var _pending_card_exit: RuntimeCard = null
var _card_exit_execution_id: int = 0
var _card_exit_effect_id: int = 0
var _hovered_runtime_card: RuntimeCard = null


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
		push_error("[BattleManager]  缺少必需的 Timeline、EntityManager 或 CardManager 引用。")
		return false
	if battle_ui == null or combat_hud == null:
		push_error("BattleManager: 缺少必需的 battle_ui 或 combat_hud 引用。")
		return false
	return entity_manager.validate_configuration() and card_manager.validate_configuration() and combat_hud.validate_configuration()


# 连接 Card、Timeline 与 Entity 子系统信号。
func _setup_connections() -> void:
	# 1. 监听 CardManager 信号
	card_manager.card_play_requested.connect(_on_card_play_requested)
	card_manager.card_play_presentation_completed.connect(_on_card_play_presentation_completed)
	combat_hud.draw_requested.connect(_on_hud_draw_requested)
	combat_hud.discard_mode_toggle_requested.connect(_on_hud_discard_toggle_requested)
	combat_hud.advance_requested.connect(_on_hud_advance_requested)
	card_manager.discard_empty_area_clicked.connect(_on_discard_empty_area_clicked)
	card_manager.card_discarded.connect(_on_hud_card_discarded.unbind(1))
	card_manager.player_hand_deck.discard_mode_changed.connect(combat_hud.set_discard_mode)
	card_manager.player_hand_deck.discard_mode_changed.connect(_on_preview_discard_mode_changed)
	card_manager.card_hover_changed.connect(_on_card_hover_changed)

	# 2. 监听 Timeline 信号
	timeline.action_triggered.connect(_on_timeline_action_triggered)
	timeline.time_advanced.connect(_on_timeline_time_advanced)
	timeline.timeline_advancement_finished.connect(_on_timeline_advancement_finished)
	timeline.pending_action_changed.connect(_on_timeline_pending_action_changed)

	# 3. 监听 EntityManager 信号
	entity_manager.enemy_action_generated.connect(_on_enemy_action_generated)
	entity_manager.visual_effect_generated.connect(_on_visual_effect_generated)
	entity_manager.entity_died.connect(_on_entity_died)
	entity_manager.health_damage_applied.connect(_on_health_damage_applied)


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
	_hovered_runtime_card = null
	combat_hud.clear_intent_preview()
	battle_result = BattleResult.NONE
	_presentation_input_ready = false
	_internal_input_locked = true
	_apply_battle_presentation()
	_apply_effective_input_lock()
	print("[BattleManager] 战斗初始化启动...")

	# 所有可恢复校验已通过，再按实体、卡牌顺序写入状态。
	if not timeline.reset_for_battle():
		_secure_failed_startup_state()
		return false
	_clear_action_presentation()
	_reset_card_exit_tracking()
	_enemy_action_schedule_succeeded = false
	_last_replenished_enemy_action = null
	if not entity_manager.initialize(external_player_data, enemy_id) or not _enemy_action_schedule_succeeded:
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
	_clear_action_presentation(true)
	_reset_card_exit_tracking()
	if timeline != null:
		timeline.cancel_advancement()
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


# HUD 按钮仍调用现有 Battle 入口，弃牌模式时不接收这两类请求。
func _on_hud_draw_requested() -> void:
	if not card_manager.player_hand_deck.is_discard_mode_active:
		request_draw_to_full()


func _on_hud_advance_requested() -> void:
	if not card_manager.player_hand_deck.is_discard_mode_active:
		request_advance_time()


# 弃牌按钮只切换手牌模式，不直接修改牌堆。
func _on_hud_discard_toggle_requested() -> void:
	var hand := card_manager.player_hand_deck
	if hand.is_discard_mode_active:
		hand.set_discard_mode(false)
	elif _can_accept_player_control():
		hand.set_discard_mode(true)


# 空白点击与成功弃牌均结束手牌模式。
func _on_discard_empty_area_clicked() -> void:
	card_manager.player_hand_deck.set_discard_mode(false)


func _on_hud_card_discarded() -> void:
	card_manager.player_hand_deck.set_discard_mode(false)


# 手牌悬停只保存当前运行时卡牌，实际命中列表在刷新时重算。
func _on_card_hover_changed(runtime_card: RuntimeCard) -> void:
	_hovered_runtime_card = runtime_card
	if runtime_card == null:
		combat_hud.clear_intent_preview()
	_queue_hud_refresh()


# 弃牌模式抢占悬停表现；退出后读取仍在悬停的卡牌。
func _on_preview_discard_mode_changed(active: bool) -> void:
	if active:
		combat_hud.clear_intent_preview()
	else:
		_hovered_runtime_card = card_manager.player_hand_deck.get_hovered_runtime_card()
	_queue_hud_refresh()

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
	var card_exit_started := card_manager.confirm_play_card(runtime_card)
	_pending_card_exit = runtime_card if card_exit_started else null
	_card_exit_execution_id = 0
	_card_exit_effect_id = 0

	# 3. 将 RuntimeCard 提交给 Timeline，转换并启动时间推进
	timeline.receive_card(runtime_card, "player", "enemy")


# 已确认出牌的离场完成；若其行动已经开始，归还对应凭据。
func _on_card_play_presentation_completed(runtime_card: RuntimeCard) -> void:
	if runtime_card != _pending_card_exit:
		return
	_pending_card_exit = null
	var execution_id := _card_exit_execution_id
	var effect_id := _card_exit_effect_id
	_card_exit_execution_id = 0
	_card_exit_effect_id = 0
	if effect_id > 0:
		notify_visual_completed(execution_id, effect_id)

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
	var future_actions := timeline.get_scheduled_enemy_action_snapshots(100)
	combat_hud.display_state({
		"player": _get_entity_display_data(entity_manager.player_entity),
		"enemies": enemies,
		"piles": {"hand": card_manager.hand_pile.size(), "limit": card_manager.hand_limit,
			"draw": card_manager.draw_pile.size(), "discard": card_manager.discard_pile.size()},
		"current_time": timeline.current_time,
		"future_actions": future_actions,
		"preview_action_ids": _get_card_preview_action_ids(future_actions),
		"scheduled_actions": timeline.get_scheduled_enemy_action_snapshots(1000000),
		"input_allowed": is_battle_active and not is_battle_input_locked(),
		"is_advancing": timeline.is_advancing,
		"has_pending_action": timeline.has_pending_action(),
		"battle_ended": battle_result != BattleResult.NONE,
	})


# Timeline 的推进含目标时刻；同刻 priority 只影响结算先后，不改变已排期行动的可达性。
func _get_card_preview_action_ids(future_actions: Array[Dictionary]) -> Array[int]:
	var ids: Array[int] = []
	if _hovered_runtime_card == null or not _can_accept_player_control() or not battle_ui.visible:
		return ids
	if card_manager.player_hand_deck.is_discard_mode_active or not card_manager.hand_pile.has(_hovered_runtime_card):
		return ids
	var target_time := timeline.current_time + _hovered_runtime_card.get_time_cost()
	var card_trigger_time := timeline.current_time if _hovered_runtime_card.get_priority() == 0 else target_time
	var reached_time := maxi(target_time, card_trigger_time)
	for action in future_actions:
		if int(action.trigger_time) <= reached_time:
			ids.append(int(action.action_instance_id))
	return ids


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
	if not is_battle_active or action == null or not timeline.is_pending_action(action):
		return
	_next_execution_id += 1
	_active_execution_id = _next_execution_id
	_active_action = action
	_transition_wait_execution_id = 0
	_next_effect_id = 0
	_pending_presentation_effects.clear()
	_presentation_dispatch_open = true
	if action.is_player and _pending_card_exit != null:
		_card_exit_execution_id = _active_execution_id
		_card_exit_effect_id = _register_presentation_effect()
	if not action.is_player and action.action_type == "attack":
		var effect_id := _register_presentation_effect() if enemy_attack_started.has_connections() else 0
		enemy_attack_started.emit(action.source_id, _active_execution_id, effect_id)
	# 1. 实体数值结算：交由 EntityManager 结算护盾、生命等属性冲击与实体 Buff
	entity_manager.execute_action(action)

	# 2. 卡牌增益结算：若该行动包含对卡牌的修改，转发给 CardManager
	for card_buff in action.card_buffs:
		card_manager.apply_buff_to_all_hand_cards(card_buff)

	# 派发窗口关闭后，只有全部实际启动的表现均完成才确认原行动。
	_presentation_dispatch_open = false
	_try_finish_action_presentation()


# 为本次行动登记一个视觉完成凭据；同步失败也须归还该凭据。
func _register_presentation_effect() -> int:
	if not _presentation_dispatch_open or not is_battle_active or _active_action == null:
		return 0
	_next_effect_id += 1
	_pending_presentation_effects[_next_effect_id] = true
	return _next_effect_id


# 只接受当前行动尚未完成的效果，旧回调无法放行新行动。
func notify_visual_completed(execution_id: int, effect_id: int) -> bool:
	if execution_id <= 0 or execution_id != _active_execution_id:
		return false
	if not _pending_presentation_effects.has(effect_id):
		return false
	_pending_presentation_effects.erase(effect_id)
	_try_finish_action_presentation()
	return true


# 全部表现结束后等待可配置间隙，再补充敌方排期并释放 Timeline 门闩。
func _try_finish_action_presentation() -> void:
	if _presentation_dispatch_open or not _pending_presentation_effects.is_empty():
		return
	var action := _active_action
	if action == null:
		return
	if not _is_action_presentation_current(action, _active_execution_id):
		_clear_action_presentation(true)
		return
	if action_transition_delay > 0.0:
		var execution_id := _active_execution_id
		if _transition_wait_execution_id == execution_id:
			return
		_transition_wait_execution_id = execution_id
		_wait_for_action_transition_delay(action, execution_id)
		return
	_complete_action_presentation(action, _active_execution_id)


# 等待期间用执行身份令牌隔离已取消或已替换的行动。
func _wait_for_action_transition_delay(action: CombatAction, execution_id: int) -> void:
	await get_tree().create_timer(action_transition_delay, false).timeout
	if _transition_wait_execution_id != execution_id:
		return
	_transition_wait_execution_id = 0
	if not _is_action_presentation_current(action, execution_id):
		if _active_action == action and _active_execution_id == execution_id:
			_clear_action_presentation(true)
		return
	_complete_action_presentation(action, execution_id)


# 仅在等待结束且原行动仍有效时补排敌人并确认完成。
func _complete_action_presentation(action: CombatAction, execution_id: int) -> void:
	if _presentation_dispatch_open or not _pending_presentation_effects.is_empty():
		return
	if not _is_action_presentation_current(action, execution_id):
		if _active_action == action and _active_execution_id == execution_id:
			_clear_action_presentation(true)
		return
	if not action.is_player and action != _last_replenished_enemy_action:
		_enemy_action_schedule_succeeded = false
		if entity_manager.plan_next_enemy_action(timeline.current_time, action.source_id):
			if _enemy_action_schedule_succeeded:
				_last_replenished_enemy_action = action
			else:
				push_error("BattleManager ： Enemy action replenishment failed: Timeline rejected the action")
		else:
			push_error("BattleManager ： Enemy action replenishment failed: actor is unavailable or planning failed")
	_clear_action_presentation()
	timeline.notify_action_finished(action)


# 校验行动身份、执行身份与 Timeline 门闩仍然匹配。
func _is_action_presentation_current(action: CombatAction, execution_id: int) -> bool:
	return (
		is_battle_active
		and action != null
		and _active_action == action
		and _active_execution_id == execution_id
		and timeline.is_pending_action(action)
	)


# 战斗结束或重启时丢弃旧行动的全部视觉完成凭据。
func _clear_action_presentation(cancel_effects: bool = false) -> void:
	var cancelled_execution_id := _active_execution_id if cancel_effects else 0
	_active_action = null
	_active_execution_id = 0
	_transition_wait_execution_id = 0
	_next_effect_id = 0
	_pending_presentation_effects.clear()
	_presentation_dispatch_open = false
	if cancelled_execution_id > 0:
		_reset_card_exit_tracking()
		action_presentation_cancelled.emit(cancelled_execution_id)


# 清除上一张已确认出牌卡牌的离场身份。
func _reset_card_exit_tracking() -> void:
	_pending_card_exit = null
	_card_exit_execution_id = 0
	_card_exit_effect_id = 0


# 时间轴流动过程中分段广播流逝时间：推进手牌限时 Buff
func _on_timeline_time_advanced(delta_time: int) -> void:
	card_manager.advance_hand_buffs_time(delta_time)
	entity_manager.advance_player_resource_regeneration(delta_time)


# 单次出牌导致的时间推移与沿途动作全部结算完成
func _on_timeline_advancement_finished() -> void:
	if is_battle_active:
		_set_internal_input_locked(false)


# 外部取消原行动时立即撤销表现凭据和在途效果。
func _on_timeline_pending_action_changed(is_pending: bool) -> void:
	if not is_pending and _active_action != null and not timeline.is_pending_action(_active_action):
		_clear_action_presentation(true)

#endregion


#region 子系统事件中继与转发

# 敌人 AI 决策完毕，将生成的行动压入时间轴排期
func _on_enemy_action_generated(action: CombatAction) -> void:
	_enemy_action_schedule_succeeded = false
	if not _is_starting_battle and not is_battle_active:
		push_error("BattleManager ： Enemy action scheduling failed: battle is inactive")
		return
	_enemy_action_schedule_succeeded = timeline.add_action(action)
	if _enemy_action_schedule_succeeded:
		print("BattleManager ： Enemy action scheduled at time %d for %s" % [action.trigger_time, action.source_id])
	else:
		push_error("BattleManager ： Enemy action scheduling failed for %s" % action.source_id)


# 转发实体/卡牌系统的视觉请求给外部展示层
func _on_visual_effect_generated(visual_type: String, data: Dictionary) -> void:
	visual_effect_requested.emit(visual_type, data)


# 将已经发生的生命损失向远征层报告，不让实体依赖世界表现节点。
func _on_health_damage_applied(target_id: String, source_id: String, amount: float) -> void:
	var effect_id := _register_presentation_effect() if health_damage_applied.has_connections() else 0
	health_damage_applied.emit(target_id, source_id, amount, _active_execution_id, effect_id)


# 实体阵亡结算
func _on_entity_died(entity: CombatEntity) -> void:
	if not is_battle_active:
		return
	is_battle_active = false
	_hovered_runtime_card = null
	combat_hud.clear_intent_preview()
	_presentation_input_ready = false
	_internal_input_locked = true
	_clear_action_presentation(true)
	timeline.cancel_advancement()
	_last_replenished_enemy_action = null
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
	if not battle_ui.visible:
		_hovered_runtime_card = null
		combat_hud.clear_intent_preview()
	if not battle_ui.visible and card_manager != null and card_manager.player_hand_deck != null:
		card_manager.player_hand_deck.set_discard_mode(false)
		if combat_hud != null:
			combat_hud.hide_intent_tooltip()


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
	if should_lock:
		_hovered_runtime_card = null
		combat_hud.clear_intent_preview()
	input_lock_changed.emit(should_lock)
	card_manager.set_input_locked(should_lock)


#endregion
