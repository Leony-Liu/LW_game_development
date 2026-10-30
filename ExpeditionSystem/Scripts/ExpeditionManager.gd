## 协调一次远征内的 World 与 Battle 边界。
## 持有独立 ExpeditionPlayerData，并上报死亡确认。
extends Node

const ExpeditionPlayerData = preload("res://Scripts/RefCounted/ExpeditionPlayerData.gd")

signal death_confirmed
signal return_to_base_requested
signal extraction_requested(operation_id: int)
signal soul_balance_changed(current_balance: int)

enum TerminalState { ACTIVE, EXTRACTING, DEAD }
var _terminal_state := TerminalState.ACTIVE
var _extraction_operation_id := 0

@export var world_manager: WorldManager
@export var battle_manager: BattleManager
@export var result_ui: ExpeditionResultUI
@export var weapon_deck_editor: Control
@export var expedition_map: Control

@export_category("玩家战斗属性")
@export var player_attributes_configured: bool = false
@export var player_entity_id: String = ""
@export var player_entity_name: String = ""
@export var player_max_hp: float = 0.0
@export var player_current_hp: float = 0.0
@export var player_shield: float = 0.0
@export var player_max_stamina: float = 0.0
@export var player_current_stamina: float = 0.0
@export var player_stamina_regen_rate: float = 0.0
@export var player_max_mana: float = 0.0
@export var player_current_mana: float = 0.0
@export var player_mana_regen_rate: float = 0.0
@export var player_custom_properties: Dictionary = {}

var _is_starting_battle := false
var _result_pending := false
var _deck_initialized := false
var _expedition_player_data: ExpeditionPlayerData
var _deck_viewer_open := false
var _map_open := false
var _encounter_reward_active := false
var _encounter_soul_reward: int = 0
var _encounter_reward_claimed := false


# 当前远征的唯一终局门闩，同时拒绝战斗、结果和世界转换冲突。
func _can_begin_terminal_operation() -> bool:
	return (
		is_inside_tree() and owner != null and get_tree().current_scene == owner
		and _deck_initialized and _terminal_state == TerminalState.ACTIVE
		and is_instance_valid(world_manager) and is_instance_valid(battle_manager)
		and world_manager.can_interact_in_exploration()
		and not _is_starting_battle and not _result_pending
		and not battle_manager.is_battle_active and not battle_manager.is_starting_battle()
	)


# L 只供开发调试，不能作为发布版的撤离或结算路径。
func can_return_to_base() -> bool:
	return OS.is_debug_build() and _can_begin_terminal_operation()


# 上层持有终局状态，设施只接收当前交互是否可用。
func _process(_delta: float) -> void:
	if _encounter_reward_active and is_instance_valid(battle_manager) and not battle_manager.is_battle_active and battle_manager.battle_result == BattleManager.BattleResult.NONE:
		_clear_encounter_reward()
	if _map_open and not _can_keep_map_open():
		_close_expedition_map(false)
	if _deck_viewer_open and not _can_keep_deck_viewer_open():
		_close_deck_viewer(false)
	if is_instance_valid(world_manager):
		world_manager.update_extraction_interaction(_can_begin_terminal_operation())


# 接受只代表已锁定操作并上报，应用层仍须验证结算及保存。
func request_extraction(room: RoomData, facility: Node3D) -> bool:
	if not _can_begin_terminal_operation() or not world_manager.is_extraction_context_valid(room, facility):
		return false
	if not extraction_requested.has_connections():
		world_manager.show_extraction_status("撤离不可用：应用处理入口未连接。")
		push_error("[ExpeditionManager] 撤离请求失败：应用处理入口未连接；保留远征。")
		return false
	_terminal_state = TerminalState.EXTRACTING
	_close_expedition_map(false)
	_close_deck_viewer(false)
	_extraction_operation_id += 1
	world_manager.update_extraction_interaction(false)
	print("[ExpeditionManager] 撤离请求已接受，开始校验结算依赖。")
	extraction_requested.emit(_extraction_operation_id)
	return true


# 失败只释放匹配操作，死亡或旧请求回调不能重新打开远征。
func reject_extraction(operation_id: int, reason: String) -> bool:
	if _terminal_state != TerminalState.EXTRACTING or operation_id != _extraction_operation_id:
		return false
	_terminal_state = TerminalState.ACTIVE
	world_manager.show_extraction_status(reason)
	world_manager.update_extraction_interaction(_can_begin_terminal_operation())
	return true


# 上层在处理通知时校验操作身份，避免旧场景通知提交终局。
func is_extraction_pending(operation_id: int) -> bool:
	return _terminal_state == TerminalState.EXTRACTING and operation_id == _extraction_operation_id

# 在焦点遍历前消费 Tab；关闭时不拦截其他系统的 Esc。
func _input(event: InputEvent) -> void:
	if owner == null or get_tree().current_scene != owner or (event is InputEventKey and event.echo):
		return
	if event.is_action_pressed("toggle_expedition_map"):
		get_viewport().set_input_as_handled()
		if _map_open:
			_close_expedition_map(true)
		else:
			_open_expedition_map()
	elif event.is_action_pressed("toggle_weapon_deck_viewer"):
		get_viewport().set_input_as_handled()
		if _deck_viewer_open:
			_close_deck_viewer(true)
		elif _can_begin_terminal_operation() and not GameManager.is_scene_transition_pending():
			_open_deck_viewer()
	elif _deck_viewer_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_deck_viewer(true)

# M 只在既有探索资格满足且没有牌组模态时打开地图。
func _open_expedition_map() -> void:
	if _map_open or _deck_viewer_open or not _can_begin_terminal_operation() or GameManager.is_scene_transition_pending():
		return
	if not is_instance_valid(expedition_map):
		push_error("[ExpeditionManager] 地图未打开：缺少 ExpeditionMap 场景引用。")
		return
	if not world_manager.begin_expedition_map():
		return
	_map_open = true
	_on_expedition_map_updated(world_manager.get_expedition_map_snapshot())
	expedition_map.show()

# 地图期间不要求移动仍启用，而是核验 World 持有的输入挂起状态。
func _can_keep_map_open() -> bool:
	return (
		is_inside_tree() and owner != null and get_tree().current_scene == owner
		and not GameManager.is_scene_transition_pending()
		and _terminal_state == TerminalState.ACTIVE and not _is_starting_battle and not _result_pending
		and is_instance_valid(battle_manager) and not battle_manager.is_battle_active
		and not battle_manager.is_starting_battle() and is_instance_valid(world_manager)
		and world_manager.is_expedition_map_valid()
	)

# 手动关闭恢复正常探索输入；自动关闭不覆盖新世界阶段的控制状态。
func _close_expedition_map(manual: bool) -> void:
	if not _map_open:
		return
	var restore_controls := manual and _can_keep_map_open()
	_map_open = false
	if is_instance_valid(expedition_map):
		expedition_map.hide()
	if is_instance_valid(world_manager):
		world_manager.end_expedition_map(restore_controls)

# 显示层只接收 World 提供的发现快照，不自行重建探索状态。
func _on_expedition_map_updated(snapshot: Dictionary) -> void:
	if is_instance_valid(expedition_map):
		expedition_map.display_map(snapshot)

# 复用既有终局、遭遇及战斗门闩，只读传递远征 CardInstance。
func _open_deck_viewer() -> void:
	if _deck_viewer_open or not _can_begin_terminal_operation() or GameManager.is_scene_transition_pending():
		return
	if not is_instance_valid(weapon_deck_editor) or weapon_deck_editor.card_scene == null:
		push_error("[ExpeditionManager] 实战牌组未打开：共享牌组 UI 配置缺失。")
		return
	if not world_manager.begin_exploration_modal():
		return
	_deck_viewer_open = true
	weapon_deck_editor.open_combat_view(get_player_deck())

# 模态期间允许维持窗口，但任何世界、战斗或场景冲突都会使其失效。
func _can_keep_deck_viewer_open() -> bool:
	return (
		is_inside_tree() and owner != null and get_tree().current_scene == owner
		and not GameManager.is_scene_transition_pending()
		and _terminal_state == TerminalState.ACTIVE and not _is_starting_battle and not _result_pending
		and is_instance_valid(battle_manager) and not battle_manager.is_battle_active
		and not battle_manager.is_starting_battle() and is_instance_valid(world_manager)
		and world_manager.is_exploration_modal_valid()
	)

# 恢复资格必须在清理前确认；自动关闭绝不回写旧探索模式。
func _close_deck_viewer(manual: bool = true) -> void:
	if not _deck_viewer_open:
		return
	var restore_controls := manual and _can_keep_deck_viewer_open()
	_deck_viewer_open = false
	if is_instance_valid(weapon_deck_editor):
		weapon_deck_editor.close_editor()
	if is_instance_valid(world_manager):
		world_manager.end_exploration_modal(restore_controls)

# 离开场景时只清理会话，不重新启用即将退出的玩家。
func _exit_tree() -> void:
	_close_expedition_map(false)
	_close_deck_viewer(false)
	clear_player_data()


# 开发快捷键仍只上报意图；应用层另做 debug 与场景校验。
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("return_to_base") and can_return_to_base():
		get_viewport().set_input_as_handled()
		return_to_base_requested.emit()


# 初始化只发布完整副本；替换或失败时先释放上次数据。
func initialize_player_data(source: WeaponInstance, initial_soul: int = 0) -> bool:
	clear_player_data()
	var data := ExpeditionPlayerData.new()
	if not data.initialize_from_weapon(source, initial_soul):
		push_error("[ExpeditionManager] 玩家数据初始化失败；未保留远征武器。")
		return false
	_expedition_player_data = data
	data.get_wallet().balance_changed.connect(_on_soul_balance_changed)
	_deck_initialized = true
	var cards := get_player_deck()
	var content_state := "CONFIGURED_EMPTY" if cards.is_empty() else "READY"
	print("[ExpeditionManager] 玩家数据初始化完成：独立武器副本，内容状态 %s，战斗牌数量 %d。" % [content_state, cards.size()])
	return true


# 清理仅释放本次远征数据，不写入持久武器或存档。
func clear_player_data() -> void:
	_clear_encounter_reward()
	_deck_initialized = false
	if _expedition_player_data != null:
		var wallet := _expedition_player_data.get_wallet()
		if wallet != null and wallet.balance_changed.is_connected(_on_soul_balance_changed):
			wallet.balance_changed.disconnect(_on_soul_balance_changed)
		_expedition_player_data.clear()
	_expedition_player_data = null


# 未初始化时只返回安全默认值，不创建钱包。
func get_soul_balance() -> int:
	var wallet: RefCounted = _expedition_player_data.get_wallet() if _expedition_player_data != null else null
	return wallet.get_soul_balance() if wallet != null else 0


# 将收入交给远征钱包，不维护第二份余额。
func add_soul(amount: int) -> bool:
	var wallet: RefCounted = _expedition_player_data.get_wallet() if _expedition_player_data != null else null
	return wallet.add_soul(amount) if wallet != null else false


# 将支出交给远征钱包，余额不足时保留原值。
func try_spend_soul(amount: int) -> bool:
	var wallet: RefCounted = _expedition_player_data.get_wallet() if _expedition_player_data != null else null
	return wallet.try_spend_soul(amount) if wallet != null else false


# 向上转发已提交的余额变化。
func _on_soul_balance_changed(current_balance: int) -> void:
	soul_balance_changed.emit(current_balance)


# 暴露远征副本的完整武器，绝不返回 Base 来源武器。
func get_expedition_weapon() -> WeaponInstance:
	return _expedition_player_data.get_weapon_instance() if _expedition_player_data != null else null


# 保留容器访问入口，来源改为远征独立武器。
func get_player_combat_container() -> CardContainer:
	var weapon := get_expedition_weapon()
	return weapon.combat_deck if weapon != null else null


# 每场战斗与查看都从远征数据取得最新顺序副本。
func get_player_deck() -> Array[CardInstance]:
	if _expedition_player_data == null:
		push_error("[ExpeditionManager] 读取牌组失败：尚未初始化远征玩家数据。")
		return []
	return _expedition_player_data.get_combat_deck()


# 备用牌组同样按需读取，不缓存数组作为权威状态。
func get_player_reserve_deck() -> Array[CardInstance]:
	if _expedition_player_data == null:
		push_error("[ExpeditionManager] 读取备用牌组失败：尚未初始化远征玩家数据。")
		return []
	return _expedition_player_data.get_reserve_deck()


# 沿用原场景已配置的玩家属性，本次不持久化或新增数值。
func _create_player_data() -> EntityData:
	if not player_attributes_configured or player_entity_id.strip_edges().is_empty() or player_entity_name.strip_edges().is_empty():
		push_error("[ExpeditionManager] 玩家战斗属性未配置。")
		return null
	var data := EntityData.new(player_entity_id, player_entity_name)
	data.max_hp = player_max_hp
	data.current_hp = player_current_hp
	data.shield = player_shield
	data.max_stamina = player_max_stamina
	data.current_stamina = player_current_stamina
	data.stamina_regen_rate = player_stamina_regen_rate
	data.max_mana = player_max_mana
	data.current_mana = player_current_mana
	data.mana_regen_rate = player_mana_regen_rate
	data.custom_properties = player_custom_properties.duplicate(true)
	return data


# 校验依赖并接收 World 的遭遇请求。
func _ready() -> void:
	assert(world_manager != null, "ExpeditionManager: 缺少必需的 world_manager 引用。")
	assert(battle_manager != null, "ExpeditionManager: 缺少必需的 battle_manager 引用。")
	assert(result_ui != null, "ExpeditionManager: 缺少必需的 result_ui 引用。")
	if not is_instance_valid(expedition_map):
		push_error("[ExpeditionManager] 地图不可用：缺少 ExpeditionMap 引用。")
	world_manager.expedition_map_updated.connect(_on_expedition_map_updated)
	_on_expedition_map_updated(world_manager.get_expedition_map_snapshot())
	if is_instance_valid(weapon_deck_editor):
		weapon_deck_editor.close_requested.connect(_close_deck_viewer)
	else:
		push_error("[ExpeditionManager] 实战牌组查看不可用：缺少共享 WeaponDeckEditor 引用。")
	if not world_manager.encounter_requested.is_connected(_on_world_encounter_requested):
		world_manager.encounter_requested.connect(_on_world_encounter_requested)
	if not world_manager.world_state_changed.is_connected(_on_world_state_changed):
		world_manager.world_state_changed.connect(_on_world_state_changed)
	world_manager.extraction_requested.connect(request_extraction)
	if not battle_manager.battle_ended.is_connected(_on_battle_ended):
		battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.enemy_attack_started.connect(_on_enemy_attack_started)
	battle_manager.health_damage_applied.connect(_on_health_damage_applied)
	battle_manager.action_presentation_cancelled.connect(_on_action_presentation_cancelled)
	battle_manager.battle_started.connect(_on_battle_started)
	result_ui.victory_confirmed.connect(_on_victory_confirmed)
	result_ui.restart_requested.connect(_on_restart_requested)
	battle_manager.set_presentation_ready(false)


# 接收有效遭遇事实，并在启动成功后接受原请求。
func _on_world_encounter_requested(room_data: RoomData, enemy_id: int) -> void:
	var interrupted_viewer := _deck_viewer_open or _map_open
	_close_expedition_map(false)
	_close_deck_viewer(false)
	if _terminal_state != TerminalState.ACTIVE:
		_reject_encounter(room_data, "远征正在撤离或已进入死亡终局。")
		return
	if _result_pending:
		_reject_encounter(room_data, "战斗结果尚未确认。")
		return
	if _is_starting_battle:
		push_warning("ExpeditionManager: 已有 Battle 启动正在处理，拒绝重入调用。")
		return
	if battle_manager.is_battle_active:
		_reject_encounter(room_data, "Battle 已处于激活状态。")
		return
	if not _is_encounter_context_valid(room_data, enemy_id):
		_reject_encounter(room_data, "遭遇上下文已失效。", interrupted_viewer)
		return
	if not _deck_initialized:
		_reject_encounter(room_data, "尚未初始化远征玩家数据；请通过 GameManager.start_expedition() 启动。", interrupted_viewer)
		return

	_is_starting_battle = true
	var player_data := _create_player_data()
	var player_deck := get_player_deck()
	if not _are_battle_inputs_valid(player_data, player_deck):
		_reject_encounter(room_data, "未生成有效的玩家属性或远征牌组输入。", interrupted_viewer)
		return
	if not _is_encounter_context_valid(room_data, enemy_id):
		_reject_encounter(room_data, "构造 Battle 输入后遭遇上下文已失效。", interrupted_viewer)
		return

	# 与 EntityManager 使用同一敌人索引，启动前截取数值而非保留房间引用。
	var enemy_data := AllEnemyData.get_enemy(enemy_id)
	var reward := enemy_data.soul_reward if enemy_data != null else -1
	_clear_encounter_reward()
	if not battle_manager.start_battle(player_deck, player_data, enemy_id):
		_reject_encounter(room_data, "BattleManager 拒绝或未完成启动。", interrupted_viewer)
		return

	_is_starting_battle = false
	if not world_manager.resolve_encounter_request(room_data, true):
		_clear_encounter_reward()
		push_error("ExpeditionManager: Battle 已启动，但原 encounter request 接受失败。")
		return
	if reward < 0:
		push_error("[ExpeditionManager] 遭遇奖励无效：敌人模板缺失或 soul_reward 为负数；本场不发放 Soul。")
	else:
		_encounter_soul_reward = reward
		_encounter_reward_active = true
	print(
		"[ExpeditionManager] Battle 启动交接完成：房间 %s，敌人 ID %d。"
		% [room_data.room_position, enemy_id]
	)


# 校验请求仍指向 World 当前持有的原房间与敌人。
func _is_encounter_context_valid(room_data: RoomData, enemy_id: int) -> bool:
	if room_data == null or not room_data.has_enemies:
		return false
	if not world_manager.is_encounter_pending(room_data):
		return false
	if room_data.enemy_id != enemy_id:
		return false
	if world_manager.current_state != WorldManager.WorldState.EXPLORE:
		return false
	var current_room: RoomData = world_manager.mapdata.get("rooms", {}).get(
		world_manager.current_room_coords
	)
	if current_room != room_data:
		return false
	return world_manager.has_valid_encounter_approach(room_data, enemy_id)


# 玩家属性是必需输入；缺失卡牌模板由 Battle 转换时跳过。
func _are_battle_inputs_valid(
	player_data: EntityData,
	player_deck: Array[CardInstance]
) -> bool:
	if player_data == null:
		return false
	return true


# 将世界阶段转换为 Battle 的表现门闩，不干预 Battle 内部输入锁。
func _on_world_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state == WorldManager.WorldState.INIT:
		_clear_encounter_reward()
	if current_state != WorldManager.WorldState.EXPLORE:
		_close_expedition_map(false)
		_close_deck_viewer(false)
	var presentation_ready := current_state == WorldManager.WorldState.BATTLE
	if not battle_manager.set_presentation_ready(presentation_ready):
		push_error("ExpeditionManager: World 已进入 BATTLE，但 Battle 尚未激活。")


# 接收 Battle 的最终结果，并等待玩家选择后续远征动作。
func _on_battle_ended(is_player_victory: bool) -> void:
	_close_expedition_map(false)
	_close_deck_viewer(false)
	if not is_player_victory:
		_clear_encounter_reward()
		_terminal_state = TerminalState.DEAD
	else:
		settle_active_encounter_reward()
	_result_pending = true
	result_ui.show_result(is_player_victory)


# 仅在本场权威胜利后结算，先锁定领取状态以防信号重入。
func settle_active_encounter_reward() -> bool:
	if not _encounter_reward_active or _encounter_reward_claimed:
		return false
	if not is_instance_valid(battle_manager) or battle_manager.is_battle_active or battle_manager.battle_result != BattleManager.BattleResult.VICTORY:
		if is_instance_valid(battle_manager) and not battle_manager.is_battle_active and battle_manager.battle_result == BattleManager.BattleResult.NONE:
			_clear_encounter_reward()
		return false
	if _expedition_player_data == null or _expedition_player_data.get_wallet() == null or _encounter_soul_reward < 0:
		push_error("[ExpeditionManager] 遭遇奖励结算失败：缺少远征钱包或奖励无效。")
		return false
	_encounter_reward_claimed = true
	if _encounter_soul_reward == 0:
		return true
	if not add_soul(_encounter_soul_reward):
		_encounter_reward_claimed = false
		push_error("[ExpeditionManager] 遭遇奖励入账失败：钱包拒绝收入；奖励未发放。")
		return false
	return true


# 初始化失败、场景清理或新战斗启动时失效旧上下文。
func _clear_encounter_reward() -> void:
	_encounter_reward_active = false
	_encounter_soul_reward = 0
	_encounter_reward_claimed = false


# 战斗发出执行事件，World 决定当前房间是否有可用模型。
func _on_enemy_attack_started(source_id: String, execution_id: int, effect_id: int) -> void:
	var completion := _on_presentation_effect_completed.bind(execution_id, effect_id)
	if not world_manager.show_enemy_attack_feedback(source_id, completion):
		_on_presentation_effect_completed(execution_id, effect_id)


# 只将实际生命损失映射为对应阵营的表现请求。
func _on_health_damage_applied(target_id: String, source_id: String, _amount: float, execution_id: int, effect_id: int) -> void:
	var completion := _on_presentation_effect_completed.bind(execution_id, effect_id)
	if target_id == "player":
		if world_manager.show_player_damage_feedback(completion):
			return
	elif source_id == "player":
		if world_manager.show_enemy_hit_feedback(target_id, completion):
			return
	_on_presentation_effect_completed(execution_id, effect_id)


# 仅将当前效果的完成凭据归还给 BattleManager。
func _on_presentation_effect_completed(execution_id: int, effect_id: int) -> void:
	if effect_id > 0:
		battle_manager.notify_visual_completed(execution_id, effect_id)


# 已取消行动的模型与镜头效果不应延续至下一次执行。
func _on_action_presentation_cancelled(_execution_id: int) -> void:
	world_manager.cancel_combat_feedback()


# 复用 BattleSystem 时清除上场结算后仍在播放的占位效果。
func _on_battle_started() -> void:
	_clear_encounter_reward()
	_close_expedition_map(false)
	_close_deck_viewer(false)
	world_manager.cancel_combat_feedback()


# 胜利确认后通过 World API 清敌并恢复探索。
func _on_victory_confirmed() -> void:
	if not _result_pending or battle_manager.battle_result != BattleManager.BattleResult.VICTORY:
		return
	if not world_manager.finish_battle():
		push_error("ExpeditionManager: 胜利确认后无法恢复探索。")
		return
	_result_pending = false
	result_ui.hide_result()


# 沿用失败确认入口，将保存与返回基地交给应用级拥有者。
func _on_restart_requested() -> void:
	if not _result_pending or battle_manager.battle_result != BattleManager.BattleResult.DEFEAT:
		return
	death_confirmed.emit()


# 释放失败请求并恢复启动门闩，使 World 可以安全重试。
func _reject_encounter(room_data: RoomData, reason: String, interrupted_viewer: bool = false) -> void:
	_is_starting_battle = false
	push_warning("ExpeditionManager: %s" % reason)
	if not world_manager.is_encounter_pending(room_data):
		return
	if not world_manager.resolve_encounter_request(room_data, false):
		push_error("ExpeditionManager: 无法释放对应的 encounter request。")
		return
	# 遭遇失败后由 World 重新进入有效探索，不能遗留已关闭窗口的控制锁。
	if interrupted_viewer and _terminal_state == TerminalState.ACTIVE and not _result_pending and not battle_manager.is_battle_active and world_manager.current_state == WorldManager.WorldState.EXPLORE:
		world_manager.enter_explore_mode()
