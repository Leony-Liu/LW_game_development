## 管理当前地图、房间与探索状态，并向远征协调器上报遇敌事实。
## 不直接启动战斗，也不组装玩家或牌组数据。
class_name WorldManager
extends Node

signal encounter_requested(room_data: RoomData, enemy_id: int)
signal world_state_changed(previous_state: int, current_state: int)

enum WorldState {
	INIT,             # 初始化生成阶段
	EXPLORE,          # 探索模式
	PREPARING_BATTLE, # 准备战斗模式
	BATTLE            # 正式战斗模式
}

@export_group("子节点绑定")
@export var world_generator: WorldGenerator
@export var room_set: RoomSet
@export var door_set: DoorSet
@export var player_visual: PlayerVisualManager

@export_group("关卡配置")
## 默认地图蓝图配置（可拖入配置好的 .tres 资源）
@export var default_blueprint: MapBlueprint

var current_state: WorldState = WorldState.INIT
var mapdata: Dictionary = {}
var current_room_coords: Vector2 = Vector2.ZERO
var _pending_encounter_room: RoomData = null
var _last_resolved_encounter_room: RoomData = null
var _last_encounter_was_accepted: bool = false
var _preparation_transition_id: int = 0
var _preparation_room: RoomData = null
var _preparation_target: Node3D = null


# 初始化门事件监听并生成默认地图。
func _ready() -> void:
	# 监听 DoorSet 的开门中继信号
	if door_set:
		door_set.door_opened_relay.connect(_on_door_opened)
	if player_visual and not player_visual.encounter_approach_finished.is_connected(
		_on_encounter_approach_finished
	):
		player_visual.encounter_approach_finished.connect(_on_encounter_approach_finished)

	# 启动时执行初始化生成
	init_map(default_blueprint)


# 校验并上报房间遭遇；重复或无消费者的请求不会改变 World 状态。
func report_encounter(room_data: RoomData) -> bool:
	if current_state != WorldState.EXPLORE:
		push_warning("[WorldManager] 仅在 EXPLORE 接受遭遇上报。")
		return false
	if _pending_encounter_room != null:
		push_warning("[WorldManager] 已有待处理的遭遇请求，忽略重复上报。")
		return false
	if room_data == null:
		push_error("[WorldManager] 无法上报遭遇：RoomData 为空。")
		return false
	if not room_data.has_enemies:
		push_error("[WorldManager] 无法上报遭遇：目标房间没有敌人。")
		return false
	if room_data.enemy_id < 0:
		push_error("[WorldManager] 无法上报遭遇：enemy_id 无效。")
		return false
	if AllEnemyData.get_enemy(room_data.enemy_id) == null:
		push_error("[WorldManager] 无法上报遭遇：找不到 enemy_id %d。" % room_data.enemy_id)
		return false
	if not encounter_requested.has_connections():
		push_warning("[WorldManager] 遭遇请求没有消费者，保持探索状态。")
		return false

	_last_resolved_encounter_room = null
	_last_encounter_was_accepted = false
	_pending_encounter_room = room_data
	encounter_requested.emit(room_data, room_data.enemy_id)
	if _pending_encounter_room == room_data:
		push_error("[WorldManager] 遭遇请求未被同步处理，已自动释放 pending 状态。")
		_pending_encounter_room = null
		return false
	return _last_resolved_encounter_room == room_data and _last_encounter_was_accepted


# 由远征协调器结束当前请求；只有明确接受后才进入战斗准备状态。
func resolve_encounter_request(room_data: RoomData, should_prepare_battle: bool) -> bool:
	if _pending_encounter_room == null:
		push_warning("[WorldManager] 没有可结束的遭遇请求。")
		return false
	if room_data != _pending_encounter_room:
		push_error("[WorldManager] 遭遇请求房间不匹配，拒绝结束请求。")
		return false

	var resolution_succeeded := true
	var encounter_accepted := false
	if should_prepare_battle:
		resolution_succeeded = enter_preparing_battle_mode(room_data)
		encounter_accepted = resolution_succeeded
		if not resolution_succeeded:
			push_error("[WorldManager] 遭遇无法进入战斗准备状态，已释放 pending 请求。")

	# 匹配请求无论接受或拒绝都必须结束，避免失败后永久阻塞重试。
	_pending_encounter_room = null
	_last_resolved_encounter_room = room_data
	_last_encounter_was_accepted = encounter_accepted
	return resolution_succeeded


# 查询指定房间是否仍是当前唯一的待处理遭遇。
func is_encounter_pending(room_data: RoomData) -> bool:
	return room_data != null and _pending_encounter_room == room_data


# 校验原房间、敌人身份和表现依赖均能启动接近运镜。
func has_valid_encounter_approach(room_data: RoomData, enemy_id: int) -> bool:
	if room_data == null or room_data.enemy_id != enemy_id:
		return false
	if room_set == null or player_visual == null:
		return false
	var target := room_set.get_encounter_approach_target(room_data)
	return target != null and player_visual.can_start_encounter_approach(target)


## 生成地图（传入 MapBlueprint 驱动整个生成流水线）
func init_map(blueprint: MapBlueprint = null) -> void:
	current_state = WorldState.INIT

	if not world_generator or not room_set or not door_set:
		push_error("[WorldManager] 缺少生成器或 Set 节点引用！")
		return

	# 蓝图优先级判定：传参 > 检查器绑定的默认资源 > 纯代码新实例兜底
	var target_blueprint: MapBlueprint = blueprint
	if not target_blueprint:
		target_blueprint = default_blueprint if default_blueprint else MapBlueprint.new()

	# 1. 驱动算法生成地图蓝本数据
	mapdata = world_generator.generate(target_blueprint)

	# 2. 分发数据给两个 Set 节点进行实体装配
	room_set.build_rooms(mapdata)
	door_set.build_doors(mapdata)

	# 3. 设置初始房间与状态
	current_room_coords = Vector2.ZERO
	enter_explore_mode()


## 世界阶段切换
# 进入探索模式
func enter_explore_mode() -> bool:
	_preparation_transition_id += 1
	_preparation_room = null
	_preparation_target = null
	if player_visual == null or not player_visual.change_mode("explore"):
		push_error("[WorldManager] 无法进入 EXPLORE：PlayerVisualManager 不可用。")
		return false
	_set_world_state(WorldState.EXPLORE)
	print("[WorldManager] 进入探索模式")
	return true


# 进入战斗准备模式（运镜、锁定玩家控制、播入场动效）
func enter_preparing_battle_mode(target_room: RoomData) -> bool:
	if current_state != WorldState.EXPLORE:
		push_error("[WorldManager] 仅能从 EXPLORE 进入 PREPARING_BATTLE。")
		return false
	var current_room: RoomData = mapdata.get("rooms", {}).get(current_room_coords)
	if target_room == null or target_room != current_room:
		push_error("[WorldManager] 准备战斗的房间不是当前有效房间。")
		return false
	if room_set == null or player_visual == null:
		push_error("[WorldManager] 准备战斗前缺少 RoomSet 或 PlayerVisualManager。")
		return false
	var approach_target := room_set.get_encounter_approach_target(target_room)
	if approach_target == null or not player_visual.can_start_encounter_approach(approach_target):
		push_error("[WorldManager] 准备战斗前缺少有效的敌人接近目标或玩家表现依赖。")
		return false
	if not player_visual.change_mode("preparing_battle"):
		push_error("[WorldManager] 无法切换到战斗准备表现状态。")
		return false

	_preparation_transition_id += 1
	var transition_id := _preparation_transition_id
	_preparation_room = target_room
	_preparation_target = approach_target
	if not player_visual.start_encounter_approach(approach_target, transition_id):
		_preparation_room = null
		_preparation_target = null
		player_visual.change_mode("explore")
		push_error("[WorldManager] 遇敌接近运镜启动失败。")
		return false
	_set_world_state(WorldState.PREPARING_BATTLE)
	print("[WorldManager] 进入准备战斗模式: 房间 ", target_room.room_position)
	return true


# 进入正式战斗模式
func enter_battle_mode(transition_id: int = -1, target_room: RoomData = null) -> bool:
	if current_state != WorldState.PREPARING_BATTLE:
		push_error("[WorldManager] 仅能从 PREPARING_BATTLE 进入 BATTLE。")
		return false
	if transition_id != _preparation_transition_id or target_room != _preparation_room:
		push_warning("[WorldManager] 已忽略失效的战斗准备回调。")
		return false
	var current_room: RoomData = mapdata.get("rooms", {}).get(current_room_coords)
	if target_room == null or target_room != current_room:
		push_error("[WorldManager] 战斗准备完成时目标房间已失效。")
		return false
	var current_target := room_set.get_encounter_approach_target(target_room)
	if not is_instance_valid(_preparation_target) or current_target != _preparation_target:
		push_error("[WorldManager] 战斗准备完成时敌人接近目标已失效。")
		return false
	if player_visual == null or not player_visual.change_mode("battle"):
		push_error("[WorldManager] 无法切换到战斗表现状态。")
		return false

	_preparation_room = null
	_preparation_target = null
	_set_world_state(WorldState.BATTLE)
	print("[WorldManager] 镜头就绪，进入正式战斗模式！")
	return true


# 校验运镜完成身份；失败时明确降级进入已启动的 Battle，避免永久锁定。
func _on_encounter_approach_finished(transition_id: int, succeeded: bool) -> void:
	if current_state != WorldState.PREPARING_BATTLE:
		push_warning("[WorldManager] 已忽略非准备状态的遇敌运镜回调。")
		return
	if transition_id != _preparation_transition_id or _preparation_room == null:
		push_warning("[WorldManager] 已忽略失效的遇敌运镜回调。")
		return
	var target_room := _preparation_room
	if succeeded:
		enter_battle_mode(transition_id, target_room)
		return
	_recover_from_approach_failure(transition_id, target_room)


# 运镜运行失败时保持 World/Battle 一致，显式跳过表现而不伪造成功。
func _recover_from_approach_failure(transition_id: int, target_room: RoomData) -> void:
	var current_room: RoomData = mapdata.get("rooms", {}).get(current_room_coords)
	if transition_id != _preparation_transition_id or target_room != current_room:
		push_error("[WorldManager] 遇敌运镜失败且房间上下文已失效，无法安全恢复。")
		return
	push_error("[WorldManager] 遇敌运镜失败；Battle 已启动，为避免永久锁定将直接进入 BATTLE。")
	if player_visual == null or not player_visual.change_mode("battle"):
		push_error("[WorldManager] 运镜失败后无法切换到 Battle 表现状态。")
		return
	_preparation_room = null
	_preparation_target = null
	_set_world_state(WorldState.BATTLE)


# 统一更新世界状态并广播一次变化。
func _set_world_state(next_state: WorldState) -> void:
	if current_state == next_state:
		return
	var previous_state := current_state
	current_state = next_state
	world_state_changed.emit(previous_state, current_state)


# 供 BattleSystem 或击杀逻辑回调：战斗胜利结算并回归探索
func finish_battle() -> void:
	print("[WorldManager] 战斗胜利！")
	var room_data: RoomData = mapdata.get("rooms", {}).get(current_room_coords)
	if room_data:
		room_data.has_enemies = false

	enter_explore_mode()


# 入门判断
func _on_door_opened(door_node: Node3D) -> void:
	# 仅在非战斗状态下响应进房判定
	if current_state != WorldState.EXPLORE:
		return

	if not player_visual or not player_visual.player:
		return

	var player_pos_3d := player_visual.player.global_position
	var door_pos_2d := Vector2(door_node.global_position.x, door_node.global_position.z)
	var player_pos_2d := Vector2(player_pos_3d.x, player_pos_3d.z)

	# 计算玩家相对门的朝向向量，推导出门对面房间的中心坐标
	var to_door := (door_pos_2d - player_pos_2d).normalized()
	var target_room_pos := Vector2(
		round((door_pos_2d.x + to_door.x * 4.0) / 10.0) * 10.0,
		round((door_pos_2d.y + to_door.y * 4.0) / 10.0) * 10.0
	)

	var rooms: Dictionary = mapdata.get("rooms", {})
	if rooms.has(target_room_pos):
		var target_room: RoomData = rooms[target_room_pos]
		current_room_coords = target_room_pos

		# 检查该房间是否有怪
		if target_room.has_enemies:
			report_encounter(target_room)
