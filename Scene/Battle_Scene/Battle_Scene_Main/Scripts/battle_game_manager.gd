extends Node
class_name BattleGameManager

# 由 Battlescene.tscn 当前已有配置绑定。
@export var player: Node3D
@export var enemy_slot: Node

# BattleGameManager 挂载在 BattleScene 根节点，
# 行动轴位于 Logic/ActionTimelineManager。
@onready var timeline_manager: ActionTimelineManager = ($Logic/ActionTimelineManager)

var current_enemy: Node = null
var current_enemy_ai: Node = null

enum GameState {
	NONE,
	START,
	READY,
	INPROGRESS,
	FINISHED
}

var battle_current_state: GameState = GameState.NONE

# 按下原格挡键时，玩家什么也不做并推进的时间。
const WAIT_TIME_AMOUNT: int = 10

func _ready() -> void:
	if not BattleBus.card_played.is_connected(
		_on_card_played
	):
		BattleBus.card_played.connect(
			_on_card_played
		)

	if not BattleBus.player_dealt_damage.is_connected(
		_on_player_dealt_damage
	):
		BattleBus.player_dealt_damage.connect(
			_on_player_dealt_damage
		)

	if not BattleBus.enemy_dealt_damage.is_connected(
		_on_enemy_dealt_damage
	):
		BattleBus.enemy_dealt_damage.connect(
			_on_enemy_dealt_damage
		)

	if not timeline_manager.action_resolution_requested.is_connected(
		_on_action_resolution_requested
	):
		timeline_manager.action_resolution_requested.connect(
			_on_action_resolution_requested
		)

	if not timeline_manager.time_passed.is_connected(
		_on_timeline_time_passed
	):
		timeline_manager.time_passed.connect(
			_on_timeline_time_passed
		)

	# 延迟启动，保证玩家状态机和 EnemyAI 已完成 _ready。
	call_deferred("_bootstrap_battle")

# 原 block_key 当前绑定为空格。
# 现在按下后不生成玩家行动，只推进 10 点逻辑时间。
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("block_key"):
		return

	if event is InputEventKey and event.echo:
		return

	get_viewport().set_input_as_handled()

	if battle_current_state != GameState.INPROGRESS:
		return

	if timeline_manager == null:
		return

	# 时间推进或动作播放期间不能重复等待。
	if (
		timeline_manager.is_advancing
		or timeline_manager.current_action != null
	):
		print(
			"BattleGameManager："
			+ "当前行动尚未结束，不能再次推进时间。"
		)
		return

	print(
		"BattleGameManager：玩家等待，推进 %d 时间。"
		% WAIT_TIME_AMOUNT
	)

	timeline_manager.advance_time(WAIT_TIME_AMOUNT)

# 自动依次进入战斗的三个准备阶段。
func _bootstrap_battle() -> void:
	change_battle_state(GameState.START)
	change_battle_state(GameState.READY)
	change_battle_state(GameState.INPROGRESS)


# 登记 EnemySlot 中的第一个敌人。
func _register_current_enemy() -> void:
	_disconnect_current_enemy_ai()

	if enemy_slot == null:
		current_enemy = null
		push_error("BattleGameManager：enemy_slot 未绑定。")
		return

	if enemy_slot.get_child_count() <= 0:
		current_enemy = null
		push_warning("BattleGameManager：EnemySlot 中没有敌人。")
		return

	current_enemy = enemy_slot.get_child(0)

	print(
		"BattleGameManager：已登记当前敌人 -> ",
		current_enemy.name
	)


# 将行动轴的规划请求连接到当前敌人 AI。
func _bind_current_enemy_ai() -> bool:
	if current_enemy == null:
		return false

	current_enemy_ai = current_enemy.get_node_or_null(
		"EnemyAI"
	)

	if current_enemy_ai == null:
		push_error(
			"BattleGameManager：当前敌人没有 EnemyAI 节点。"
		)
		return false

	if not current_enemy_ai.has_method(
		"on_plan_requested"
	):
		push_error(
			"BattleGameManager：EnemyAI 缺少 "
			+ "on_plan_requested()。"
		)
		current_enemy_ai = null
		return false

	var callback := Callable(
		current_enemy_ai,
		"on_plan_requested"
	)

	if not timeline_manager.enemy_plan_requested.is_connected(
		callback
	):
		timeline_manager.enemy_plan_requested.connect(
			callback
		)

	print("BattleGameManager：行动轴已连接当前敌人 AI。")

	return true


func _disconnect_current_enemy_ai() -> void:
	if current_enemy_ai == null:
		return

	if not is_instance_valid(current_enemy_ai):
		current_enemy_ai = null
		return

	var callback := Callable(
		current_enemy_ai,
		"on_plan_requested"
	)

	if timeline_manager.enemy_plan_requested.is_connected(
		callback
	):
		timeline_manager.enemy_plan_requested.disconnect(
			callback
		)

	current_enemy_ai = null


# 战斗阶段切换。
func change_battle_state(
	new_state: GameState,
	context: Dictionary = {}
) -> void:
	if battle_current_state == new_state:
		return

	battle_current_state = new_state

	match battle_current_state:
		GameState.START:
			BattleBus.battle_start.emit()

		GameState.READY:
			_prepare_battle()

		GameState.INPROGRESS:
			BattleBus.battle_inprogress.emit()
			_start_battle_logic()

		GameState.FINISHED:
			var winner := str(
				context.get(
					"winner",
					""
				)
			)

			BattleBus.battle_finished.emit(winner)
			_finish_battle_logic()


# 判断卡牌能否提交。
func can_play_card(card_data: Dictionary) -> bool:
	if battle_current_state != GameState.INPROGRESS:
		print("BattleGameManager：当前不在战斗进行阶段。")
		return false

	if timeline_manager.is_advancing:
		print("BattleGameManager：行动轴正在推进，暂时不能出牌。")
		return false

	if player == null or not is_instance_valid(player):
		push_error("BattleGameManager：玩家节点无效。")
		return false

	var category := str(
		card_data.get(
			"categories",
			""
		)
	)

	if category == "attack":
		if (
			current_enemy == null
			or not is_instance_valid(current_enemy)
		):
			print("BattleGameManager：当前没有有效攻击目标。")
			return false

	if not player.has_method("can_commit_card"):
		push_error(
			"BattleGameManager：玩家缺少 can_commit_card()。"
		)
		return false

	return bool(
		player.call(
			"can_commit_card",
			card_data
		)
	)


# 接收 CardBase 发出的出牌请求。
func _on_card_played(
	card_data: Dictionary,
	card_node: Control
) -> void:
	if not can_play_card(card_data):
		BattleBus.card_rejected.emit(card_node)
		return

	var action := _create_player_timeline_action(
		card_data
	)

	if action == null:
		BattleBus.card_rejected.emit(card_node)
		push_error(
			"BattleGameManager：玩家卡牌行动创建失败。"
		)
		return

	if not player.has_method("pay_card_cost"):
		BattleBus.card_rejected.emit(card_node)
		push_error(
			"BattleGameManager：玩家缺少 pay_card_cost()。"
		)
		return

	var cost_paid := bool(
		player.call(
			"pay_card_cost",
			card_data
		)
	)

	if not cost_paid:
		BattleBus.card_rejected.emit(card_node)
		return

		# 必须先把悬停预览转换为正式推进条。
	# action_committed 会同步进入 ActionTimelineManager，
	# 并可能立刻发出 time_visual_move_requested。
	BattleBus.card_timeline_preview_committed.emit(
		action.time_cost
	)

	# 预览状态准备完成后，再提交行动并开始推进时间。
	BattleBus.action_committed.emit(action)

	# 行动已提交后，卡牌才能离开手牌进入弃牌堆。
	BattleBus.card_successfully_played.emit(card_node)


# 将卡牌数据封装为统一的 TimelineAction。
func _create_player_timeline_action(
	card_data: Dictionary
) -> TimelineAction:
	var time_cost := int(
		card_data.get(
			"time_cost",
			-1
		)
	)

	if time_cost < 0:
		push_error(
			"BattleGameManager：卡牌 time_cost 不能小于 0。"
		)
		return null

	var category := str(
		card_data.get(
			"categories",
			""
		)
	)

	if category != "attack" and category != "skill":
		push_error(
			"BattleGameManager：不支持的卡牌类型：%s"
			% category
		)
		return null

	var execute_priority := clampi(
		int(
			card_data.get(
				"execute_priority",
				1
			)
		),
		0,
		3
	)

	var action := TimelineAction.new()

	# sequence_id 不再使用卡牌 ID。
	# 该编号由 ActionTimelineManager 自动分配。
	action.action_name = str(
		card_data.get(
			"name_key",
			"UNKNOWN_CARD"
		)
	)

	action.actor = player
	action.actor_side = TimelineAction.ActorSide.PLAYER
	action.time_cost = time_cost
	action.execute_priority = execute_priority

	# 保留当前 CSV 的约定：
	# execute_priority 为 0 的卡牌视为先手牌。
	action.has_initiative = execute_priority == 0

	action.advances_time = true
	action.can_be_cancelled = bool(
		card_data.get(
			"can_be_cancelled",
			true
		)
	)

	var target_type := "self"

	if category == "attack":
		target_type = "enemy"

	action.payload = {
		"action_id": str(
			card_data.get(
				"id",
				""
			)
		),
		"category": category,
		"effect_type": "card",
		"target_type": target_type,
		"action_data": card_data.duplicate(true)
	}

	return action


# 行动轴到达行动时间时，由此处分发给行动发起者。
func _on_action_resolution_requested(
	action: TimelineAction
) -> void:
	if action == null:
		return

	if (
		action.actor == null
		or not is_instance_valid(action.actor)
	):
		push_warning(
			"BattleGameManager：行动发起者已经失效。"
		)

		# 防止行动轴永久等待。
		timeline_manager.finish_action_execution(action)
		return

	if not action.actor.has_method(
		"resolve_timeline_action"
	):
		push_error(
			"BattleGameManager：行动发起者 %s "
			+ "缺少 resolve_timeline_action()。"
			% action.actor.name
		)

		timeline_manager.finish_action_execution(action)
		return

	# 这里只负责启动动作。
	# 动作结束后，角色自己发出 timeline_action_finished。
	action.actor.call(
		"resolve_timeline_action",
		action
	)

func _on_timeline_time_passed(
	amount: int,
	_current_time: int
) -> void:
	if player == null or not is_instance_valid(player):
		return

	var combat_data := player.get_node_or_null(
		"Data/CombatData"
	)

	if combat_data == null:
		return

	if combat_data.has_method(
		"recover_resources_by_time"
	):
		combat_data.recover_resources_by_time(amount)

# 玩家和敌人都使用相同的完成信号。
func _bind_timeline_actor_completion(
	actor: Node
) -> void:
	if actor == null:
		return

	if not actor.has_signal(
		&"timeline_action_finished"
	):
		push_error(
			"BattleGameManager：角色 %s "
			+ "缺少 timeline_action_finished 信号。"
			% actor.name
		)
		return

	var callback := Callable(
		self,
		"_on_actor_timeline_action_finished"
	)

	if not actor.is_connected(
		&"timeline_action_finished",
		callback
	):
		actor.connect(
			&"timeline_action_finished",
			callback
		)


func _on_actor_timeline_action_finished(
	action: TimelineAction
) -> void:
	timeline_manager.finish_action_execution(action)

# 接收玩家伤害并路由给当前敌人。
func _on_player_dealt_damage(
	payload: Dictionary
) -> void:
	if (
		current_enemy != null
		and is_instance_valid(current_enemy)
		and current_enemy.has_method("take_damage")
	):
		current_enemy.call(
			"take_damage",
			payload
		)
	else:
		print("BattleGameManager：玩家攻击没有有效目标。")


# 接收敌人伤害并路由给玩家。
func _on_enemy_dealt_damage(
	payload: Dictionary
) -> void:
	if player == null or not is_instance_valid(player):
		return

	var player_combat_data := player.get_node_or_null(
		"Data/CombatData"
	)

	if player_combat_data == null:
		push_error(
			"BattleGameManager：玩家没有 Data/CombatData。"
		)
		return

	var damage := int(
		payload.get(
			"damage",
			0
		)
	)

	var source_name := "enemy"
	var source = payload.get("source", null)

	if source != null and is_instance_valid(source):
		source_name = str(source.name)

	player_combat_data.get_hit(
		damage,
		source_name
	)


func _prepare_battle() -> void:
	_register_current_enemy()
	_bind_current_enemy_ai()

	# 连接玩家动作完成信号。
	_bind_timeline_actor_completion(player)

	# 连接当前敌人动作完成信号。
	_bind_timeline_actor_completion(current_enemy)


func _start_battle_logic() -> void:
	if current_enemy == null:
		push_warning(
			"BattleGameManager：没有敌人，无法开始敌人规划。"
		)
		return

	if current_enemy_ai == null:
		if not _bind_current_enemy_ai():
			return

	# 战斗刚开始时先让敌人规划 current_time + 100。
	timeline_manager.request_enemy_plan()


func _finish_battle_logic() -> void:
	_disconnect_current_enemy_ai()
