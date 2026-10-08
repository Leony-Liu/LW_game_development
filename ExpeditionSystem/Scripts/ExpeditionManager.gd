## 协调一次远征内的 World 与 Battle 边界。
## 校验遭遇与原型玩家输入，并执行一次可靠的 Battle 启动交接。
extends Node

@export var world_manager: WorldManager
@export var battle_manager: BattleManager
@export var prototype_player_data_provider: PrototypePlayerDataProvider

var _is_starting_battle := false


# 校验依赖并接收 World 的遭遇请求。
func _ready() -> void:
	assert(world_manager != null, "ExpeditionManager: 缺少必需的 world_manager 引用。")
	assert(battle_manager != null, "ExpeditionManager: 缺少必需的 battle_manager 引用。")
	assert(
		prototype_player_data_provider != null,
		"ExpeditionManager: 缺少必需的 prototype_player_data_provider 引用。"
	)
	if not world_manager.encounter_requested.is_connected(_on_world_encounter_requested):
		world_manager.encounter_requested.connect(_on_world_encounter_requested)
	if not world_manager.world_state_changed.is_connected(_on_world_state_changed):
		world_manager.world_state_changed.connect(_on_world_state_changed)
	battle_manager.set_presentation_ready(false)


# 接收有效遭遇事实，并在启动成功后接受原请求。
func _on_world_encounter_requested(room_data: RoomData, enemy_id: int) -> void:
	if _is_starting_battle:
		push_warning("ExpeditionManager: 已有 Battle 启动正在处理，拒绝重入调用。")
		return
	if battle_manager.is_battle_active:
		_reject_encounter(room_data, "Battle 已处于激活状态。")
		return
	if not _is_encounter_context_valid(room_data, enemy_id):
		_reject_encounter(room_data, "遭遇上下文已失效。")
		return
	if not prototype_player_data_provider.validate_configuration():
		_reject_encounter(room_data, "PrototypePlayerDataProvider 配置无效。")
		return

	_is_starting_battle = true
	var player_data := prototype_player_data_provider.get_player_data()
	var player_deck := prototype_player_data_provider.get_player_deck()
	if not _are_battle_inputs_valid(player_data, player_deck):
		_reject_encounter(room_data, "provider 未生成有效的 Battle 输入。")
		return
	if not _is_encounter_context_valid(room_data, enemy_id):
		_reject_encounter(room_data, "构造 Battle 输入后遭遇上下文已失效。")
		return

	if not battle_manager.start_battle(player_deck, player_data, enemy_id):
		_reject_encounter(room_data, "BattleManager 拒绝或未完成启动。")
		return

	_is_starting_battle = false
	if not world_manager.resolve_encounter_request(room_data, true):
		push_error("ExpeditionManager: Battle 已启动，但原 encounter request 接受失败。")
		return
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
	if room_data.enemy_id != enemy_id or enemy_id < 0:
		return false
	if world_manager.current_state != WorldManager.WorldState.EXPLORE:
		return false
	var current_room: RoomData = world_manager.mapdata.get("rooms", {}).get(
		world_manager.current_room_coords
	)
	if current_room != room_data:
		return false
	if AllEnemyData.get_enemy(enemy_id) == null:
		return false
	return world_manager.has_valid_encounter_approach(room_data, enemy_id)


# 校验 provider 输出类型与卡牌静态引用，不新增玩法数值规则。
func _are_battle_inputs_valid(
	player_data: EntityData,
	player_deck: Array[CardInstance]
) -> bool:
	if player_data == null:
		return false
	for card_instance in player_deck:
		if card_instance == null or card_instance.card_data == null:
			return false
	return true


# 将世界阶段转换为 Battle 的表现门闩，不干预 Battle 内部输入锁。
func _on_world_state_changed(_previous_state: int, current_state: int) -> void:
	var presentation_ready := current_state == WorldManager.WorldState.BATTLE
	if not battle_manager.set_presentation_ready(presentation_ready):
		push_error("ExpeditionManager: World 已进入 BATTLE，但 Battle 尚未激活。")


# 释放失败请求并恢复启动门闩，使 World 可以安全重试。
func _reject_encounter(room_data: RoomData, reason: String) -> void:
	_is_starting_battle = false
	push_warning("ExpeditionManager: %s" % reason)
	if not world_manager.is_encounter_pending(room_data):
		return
	if not world_manager.resolve_encounter_request(room_data, false):
		push_error("ExpeditionManager: 无法释放对应的 encounter request。")
