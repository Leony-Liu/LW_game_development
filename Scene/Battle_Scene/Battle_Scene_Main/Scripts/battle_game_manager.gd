extends Node
class_name BattleGameManager

# 由 Battlescene.tscn 当前已有配置绑定。
@export var player: Node3D
@export var enemy_slot: Node

# 时间轴管理器
@onready var timeline_manager: TimelineManager = ($Logic/TimelineManager)

var current_enemy: Node = null
var current_enemy_ai: Node = null

# 游戏阶段
enum GameState {
	NONE,
	START,
	READY,
	INPROGRESS,
	FINISHED
}

# 记录当前战斗阶段
var battle_current_state: GameState = GameState.NONE

# 按下原格挡键时，玩家什么也不做并推进的时间。
const WAIT_TIME_AMOUNT: int = 10

# 初始化战斗总线和时间轴信号的连接
func _ready() -> void:

	BattleBus.card_played.connect(_on_card_played)
# 绑定卡牌打出信号完毕

	BattleBus.player_dealt_damage.connect(_on_player_dealt_damage)
# 绑定玩家造成伤害信号完毕

	BattleBus.enemy_dealt_damage.connect(_on_enemy_dealt_damage)
# 绑定敌人造成伤害信号完毕

	timeline_manager.action_resolution_requested.connect(_on_action_resolution_requested)
# 绑定时间轴动作结算信号完毕

	timeline_manager.time_passed.connect(_on_timeline_time_passed)
# 绑定时间推移信号完毕

# 延迟启动，保证玩家状态机和 EnemyAI 已完成 _ready。
	call_deferred("_bootstrap_battle")
# 延迟启动战斗准备逻辑完毕

# 切换当前战斗阶段并触发对应阶段的初始化或结束逻辑
func change_battle_state(new_state: GameState, context: Dictionary = {}) -> void:
	if battle_current_state == new_state:
		return
	battle_current_state = new_state
	# 校验并更新战斗状态完毕

	match battle_current_state:
		GameState.START:
			BattleBus.battle_start.emit()
		GameState.READY:
			_prepare_battle()
		GameState.INPROGRESS:
			BattleBus.battle_inprogress.emit()
			_start_battle_logic()
		GameState.FINISHED:
			var winner := str(context.get("winner", ""))
			BattleBus.battle_finished.emit(winner)
			_finish_battle_logic()
	# 根据新状态执行对应的分支逻辑完毕

# 检查当前状态和条件下玩家是否能够打出指定的卡牌
func can_play_card(card_data: Dictionary) -> bool:
	if battle_current_state != GameState.INPROGRESS:
		print("BattleGameManager：当前不在战斗进行阶段。")
		return false
	# 检查是否处于战斗进行阶段完毕

	if timeline_manager.is_advancing:
		print("BattleGameManager：行动轴正在推进，暂时不能出牌。")
		return false
	# 检查时间轴是否处于静止状态完毕

	if player == null or not is_instance_valid(player):
		push_error("BattleGameManager：玩家节点无效。")
		return false
	# 检查玩家节点是否有效完毕

	var category := str(card_data.get("categories", ""))
	if category == "attack":
		if current_enemy == null or not is_instance_valid(current_enemy):
			print("BattleGameManager：当前没有有效攻击目标。")
			return false
	# 若为攻击卡牌则校验是否有有效目标完毕

	if not player.has_method("can_commit_card"):
		push_error("BattleGameManager：玩家缺少 can_commit_card()。")
		return false
	return bool(player.call("can_commit_card", card_data))
	# 调用玩家节点的方法进行最终校验完毕

# 处理未被截获的输入，当前仅处理玩家的防御等待操作
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("block_key"):
		return
	if event is InputEventKey and event.echo:
		return
	# 校验格挡按键输入完毕

	get_viewport().set_input_as_handled()
	# 拦截并标记输入已处理完毕

	if battle_current_state != GameState.INPROGRESS:
		return
	if timeline_manager == null:
		return
	# 校验当前战斗状态和时间轴有效性完毕

	# 时间推进或动作播放期间不能重复等待。
	if timeline_manager.is_advancing or timeline_manager.current_action != null:
		print("BattleGameManager：当前行动尚未结束，不能再次推进时间。")
		return
	# 检查当前是否允许推进时间完毕

	print("BattleGameManager：玩家等待，推进 %d 时间。" % WAIT_TIME_AMOUNT)
	timeline_manager.advance_time(WAIT_TIME_AMOUNT)
	# 执行时间推移推进逻辑完毕

# 自动执行战斗状态机的初始流转，依次进入准备和进行阶段
func _bootstrap_battle() -> void:
	change_battle_state(GameState.START)
	change_battle_state(GameState.READY)
	change_battle_state(GameState.INPROGRESS)
	# 依次推进状态机阶段完毕

# 从敌人槽位中获取并登记当前需要对战的首个敌人
func _register_current_enemy() -> void:
	_disconnect_current_enemy_ai()
	# 清理旧的敌人AI连接完毕

	if enemy_slot == null:
		current_enemy = null
		push_error("BattleGameManager：enemy_slot 未绑定。")
		return
	# 校验槽位节点是否有效完毕

	if enemy_slot.get_child_count() <= 0:
		current_enemy = null
		push_warning("BattleGameManager：EnemySlot 中没有敌人。")
		return
	# 校验槽位中是否存在敌人完毕

	current_enemy = enemy_slot.get_child(0)
	print("BattleGameManager：已登记当前敌人 -> ", current_enemy.name)
	# 记录第一个子节点为当前敌人完毕

# 将当前敌人的AI节点方法与时间轴的规划请求信号进行绑定
func _bind_current_enemy_ai() -> bool:
	if current_enemy == null:
		return false
	# 校验当前敌人是否存在完毕

	current_enemy_ai = current_enemy.get_node_or_null("EnemyAI")
	if current_enemy_ai == null:
		push_error("BattleGameManager：当前敌人没有 EnemyAI 节点。")
		return false
	# 获取敌人的AI节点完毕

	if not current_enemy_ai.has_method("on_plan_requested"):
		push_error("BattleGameManager：EnemyAI 缺少 on_plan_requested()。")
		current_enemy_ai = null
		return false
	# 校验AI节点是否具备规划方法完毕

	var callback := Callable(current_enemy_ai, "on_plan_requested")
	if not timeline_manager.enemy_plan_requested.is_connected(callback):
		timeline_manager.enemy_plan_requested.connect(callback)
	print("BattleGameManager：行动轴已连接当前敌人 AI。")
	return true
	# 连接时间轴的敌人规划信号完毕

# 断开当前敌人AI与时间轴规划请求的信号连接
func _disconnect_current_enemy_ai() -> void:
	if current_enemy_ai == null:
		return
	if not is_instance_valid(current_enemy_ai):
		current_enemy_ai = null
		return
	# 校验AI节点有效性完毕

	var callback := Callable(current_enemy_ai, "on_plan_requested")
	if timeline_manager.enemy_plan_requested.is_connected(callback):
		timeline_manager.enemy_plan_requested.disconnect(callback)
	# 断开时间轴规划信号的连接完毕

	current_enemy_ai = null
	# 清空当前敌人AI引用完毕

# 接收玩家打出卡牌的请求，校验后创建时间轴行动并扣除费用
func _on_card_played(card_data: Dictionary, card_node: Control) -> void:
	if not can_play_card(card_data):
		BattleBus.card_rejected.emit(card_node)
		return
	# 校验卡牌是否允许打出完毕

	var action := _create_player_timeline_action(card_data)
	if action == null:
		BattleBus.card_rejected.emit(card_node)
		push_error("BattleGameManager：玩家卡牌行动创建失败。")
		return
	# 将卡牌数据转换为时间轴动作完毕

	if not player.has_method("pay_card_cost"):
		BattleBus.card_rejected.emit(card_node)
		push_error("BattleGameManager：玩家缺少 pay_card_cost()。")
		return
	var cost_paid := bool(player.call("pay_card_cost", card_data))
	if not cost_paid:
		BattleBus.card_rejected.emit(card_node)
		return
	# 校验并扣除玩家卡牌费用完毕

	# 必须先把悬停预览转换为正式推进条。
	# action_committed 会同步进入 TimelineManager，
	# 并可能立刻发出 time_visual_move_requested。
	BattleBus.card_timeline_preview_committed.emit(action.time_cost)
	# 预览状态准备完成后，再提交行动并开始推进时间。
	BattleBus.action_committed.emit(action)
	# 行动已提交后，卡牌才能离开手牌进入弃牌堆。
	BattleBus.card_successfully_played.emit(card_node)
	# 提交时间轴动作并触发卡牌打出成功信号完毕

# 将传入的卡牌字典数据解析并封装为统一的时间轴动作对象
func _create_player_timeline_action(card_data: Dictionary) -> TimelineAction:
	var time_cost := int(card_data.get("time_cost", -1))
	if time_cost < 0:
		push_error("BattleGameManager：卡牌 time_cost 不能小于 0。")
		return null
	# 提取并校验卡牌的时间消耗完毕

	var category := str(card_data.get("categories", ""))
	if category != "attack" and category != "skill":
		push_error("BattleGameManager：不支持的卡牌类型：%s" % category)
		return null
	# 校验卡牌的类别是否合法完毕

	var execute_priority := clampi(int(card_data.get("execute_priority", 1)), 0, 3)
	# 提取执行优先级完毕

	var action := TimelineAction.new()
	# sequence_id 不再使用卡牌 ID。
	# 该编号由 TimelineManager 自动分配。
	action.action_name = str(card_data.get("name_key", "UNKNOWN_CARD"))
	action.actor = player
	action.actor_side = TimelineAction.ActorSide.PLAYER
	action.time_cost = time_cost
	action.execute_priority = execute_priority
	# 保留当前 CSV 的约定：
	# execute_priority 为 0 的卡牌视为先手牌。
	action.has_initiative = execute_priority == 0
	action.advances_time = true
	action.can_be_cancelled = bool(card_data.get("can_be_cancelled", true))
	# 实例化并配置基础动作属性完毕

	var target_type := "self"
	if category == "attack":
		target_type = "enemy"
	action.payload = {
		"action_id": str(card_data.get("id", "")),
		"category": category,
		"effect_type": "card",
		"target_type": target_type,
		"action_data": card_data.duplicate(true)
	}
	return action
	# 根据卡牌类别设定目标类型并组装载荷数据完毕

# 当时间轴到达行动时间时，分发行动给对应的发起者执行
func _on_action_resolution_requested(action: TimelineAction) -> void:
	if action == null:
		return
	if action.actor == null or not is_instance_valid(action.actor):
		push_warning("BattleGameManager：行动发起者已经失效。")
		# 防止行动轴永久等待。
		timeline_manager.finish_action_execution(action)
		return
	# 校验动作和发起者的有效性完毕

	if not action.actor.has_method("resolve_timeline_action"):
		push_error("BattleGameManager：行动发起者 %s 缺少 resolve_timeline_action()。" % action.actor.name)
		timeline_manager.finish_action_execution(action)
		return
	# 校验发起者是否具备处理动作的方法完毕

	# 这里只负责启动动作。
	# 动作结束后，角色自己发出 timeline_action_finished。
	action.actor.call("resolve_timeline_action", action)
	# 调用发起者的动作结算方法完毕

# 在时间轴推移时，触发玩家随时间恢复资源的逻辑
func _on_timeline_time_passed(amount: int, _current_time: int) -> void:
	if player == null or not is_instance_valid(player):
		return
	var combat_data := player.get_node_or_null("Data/CombatData")
	if combat_data == null:
		return
	# 校验玩家及其战斗数据节点完毕

	if combat_data.has_method("recover_resources_by_time"):
		combat_data.recover_resources_by_time(amount)
	# 调用资源时间恢复方法完毕

# 为指定角色的动作完成信号绑定统一的处理回调
func _bind_timeline_actor_completion(actor: Node) -> void:
	if actor == null:
		return
	if not actor.has_signal(&"timeline_action_finished"):
		push_error("BattleGameManager：角色 %s 缺少 timeline_action_finished 信号。" % actor.name)
		return
	# 校验角色节点及其信号是否存在完毕

	var callback := Callable(self, "_on_actor_timeline_action_finished")
	if not actor.is_connected(&"timeline_action_finished", callback):
		actor.connect(&"timeline_action_finished", callback)
	# 将动作完成信号连接到回调函数完毕

# 接收角色动作完成的回调，通知时间轴结束该动作的执行状态
func _on_actor_timeline_action_finished(action: TimelineAction) -> void:
	timeline_manager.finish_action_execution(action)
	# 调用时间轴的动作结束方法完毕

# 接收玩家造成的伤害数据并传递给当前的敌人目标
func _on_player_dealt_damage(payload: Dictionary) -> void:
	if current_enemy != null and is_instance_valid(current_enemy) and current_enemy.has_method("take_damage"):
		current_enemy.call("take_damage", payload)
	else:
		print("BattleGameManager：玩家攻击没有有效目标。")
	# 校验目标有效性并调用其受伤方法完毕

# 接收敌人造成的伤害数据并传递给玩家进行处理
func _on_enemy_dealt_damage(payload: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	var player_combat_data := player.get_node_or_null("Data/CombatData")
	if player_combat_data == null:
		push_error("BattleGameManager：玩家没有 Data/CombatData。")
		return
	# 校验并获取玩家战斗数据节点完毕

	var damage := int(payload.get("damage", 0))
	var source_name := "enemy"
	var source = payload.get("source", null)
	if source != null and is_instance_valid(source):
		source_name = str(source.name)
	player_combat_data.get_hit(damage, source_name)
	# 解析伤害数值和伤害来源并触发玩家受击完毕

# 战斗准备阶段，负责登记敌人并绑定双方的时间轴动作完成信号
func _prepare_battle() -> void:
	_register_current_enemy()
	_bind_current_enemy_ai()
	# 注册并绑定敌人AI完毕

	# 连接玩家动作完成信号。
	_bind_timeline_actor_completion(player)
	# 连接当前敌人动作完成信号。
	_bind_timeline_actor_completion(current_enemy)
	# 绑定玩家与敌人的动作完成信号完毕

# 战斗开始阶段，负责请求敌人进行初始的行动规划
func _start_battle_logic() -> void:
	if current_enemy == null:
		push_warning("BattleGameManager：没有敌人，无法开始敌人规划。")
		return
	if current_enemy_ai == null:
		if not _bind_current_enemy_ai():
			return
	# 校验敌人有效性并确保AI已绑定完毕

	# 战斗刚开始时先让敌人规划 current_time + 100。
	timeline_manager.request_enemy_plan()
	# 向敌人AI发起时间轴规划请求完毕

# 战斗结束阶段，负责清理和断开相关的逻辑连接
func _finish_battle_logic() -> void:
	_disconnect_current_enemy_ai()
	# 断开敌人AI信号连接完毕
