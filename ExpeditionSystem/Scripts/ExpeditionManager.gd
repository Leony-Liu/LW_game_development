## 协调一次远征内的 World 与 Battle 边界。
## 校验遭遇与原型玩家输入，并执行一次可靠的 Battle 启动交接。
extends Node

@export var world_manager: WorldManager
@export var battle_manager: BattleManager
@export var prototype_player_data_provider: PrototypePlayerDataProvider
@export var result_ui: ExpeditionResultUI

var _is_starting_battle := false
var _result_pending := false


# 校验依赖并接收 World 的遭遇请求。
func _ready() -> void:
	assert(world_manager != null, "ExpeditionManager: 缺少必需的 world_manager 引用。")
	assert(battle_manager != null, "ExpeditionManager: 缺少必需的 battle_manager 引用。")
	assert(result_ui != null, "ExpeditionManager: 缺少必需的 result_ui 引用。")
	assert(
		prototype_player_data_provider != null,
		"ExpeditionManager: 缺少必需的 prototype_player_data_provider 引用。"
	)
	if not world_manager.encounter_requested.is_connected(_on_world_encounter_requested):
		world_manager.encounter_requested.connect(_on_world_encounter_requested)
	if not world_manager.world_state_changed.is_connected(_on_world_state_changed):
		world_manager.world_state_changed.connect(_on_world_state_changed)
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


# 接收 Battle 的最终结果，并等待玩家选择后续远征动作。
func _on_battle_ended(is_player_victory: bool) -> void:
	_result_pending = true
	result_ui.show_result(is_player_victory)


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


# 失败确认后重新实例化远征场景，丢弃本次临时状态。
func _on_restart_requested() -> void:
	if not _result_pending or battle_manager.battle_result != BattleManager.BattleResult.DEFEAT:
		return
	var error := get_tree().change_scene_to_file("res://ExpeditionSystem/ExpeditionSystem.tscn")
	if error != OK:
		push_error("ExpeditionManager: 无法重新开始远征，错误码 %d。" % error)


# 释放失败请求并恢复启动门闩，使 World 可以安全重试。
func _reject_encounter(room_data: RoomData, reason: String) -> void:
	_is_starting_battle = false
	push_warning("ExpeditionManager: %s" % reason)
	if not world_manager.is_encounter_pending(room_data):
		return
	if not world_manager.resolve_encounter_request(room_data, false):
		push_error("ExpeditionManager: 无法释放对应的 encounter request。")
