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

	# 启动时执行初始化生成，失败时保持 INIT。
	if not init_map(default_blueprint):
		return


# 校验并上报待处理遭遇；返回值只表示已通知，不读取监听者的处理结果。
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
	if not encounter_requested.has_connections():
		push_warning("[WorldManager] 遭遇请求没有消费者，保持探索状态。")
		return false

	_pending_encounter_room = room_data
	encounter_requested.emit(room_data, room_data.enemy_id)
	return true


# 由远征协调器结束当前请求；只有明确接受后才进入战斗准备状态。
func resolve_encounter_request(room_data: RoomData, should_prepare_battle: bool) -> bool:
	if _pending_encounter_room == null:
		push_warning("[WorldManager] 没有可结束的遭遇请求。")
		return false
	if room_data != _pending_encounter_room:
		push_error("[WorldManager] 遭遇请求房间不匹配，拒绝结束请求。")
		return false

	var resolution_succeeded := true
	if should_prepare_battle:
		resolution_succeeded = enter_preparing_battle_mode(room_data)
		if not resolution_succeeded:
			push_error("[WorldManager] 遭遇无法进入战斗准备状态，已释放 pending 请求。")

	# 匹配请求无论接受或拒绝都必须结束，避免失败后永久阻塞重试。
	_pending_encounter_room = null
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
	return player_visual.can_present_battle() and (target == null or player_visual.can_start_encounter_approach(target))


## 生成并装配地图；只有全部必需阶段成功后才进入探索。
func init_map(blueprint: MapBlueprint = null) -> bool:
	print("WorldManager ： 地图初始化开始。")
	current_state = WorldState.INIT
	mapdata = {}
	current_room_coords = Vector2.ZERO
	_pending_encounter_room = null
	_preparation_transition_id += 1
	_preparation_room = null
	_preparation_target = null

	if not is_instance_valid(world_generator) or not is_instance_valid(room_set) or not is_instance_valid(door_set) or not is_instance_valid(player_visual):
		return _abort_map_initialization("缺少必需的生成器、RoomSet、DoorSet 或 PlayerVisualManager。")
	room_set.clear_rooms()
	door_set.clear_doors()

	# 蓝图优先级判定：传参 > 检查器绑定的默认资源 > 纯代码新实例兜底
	var target_blueprint: MapBlueprint = blueprint
	if not target_blueprint:
		target_blueprint = default_blueprint if default_blueprint else MapBlueprint.new()

	# 1. 驱动算法生成地图蓝本数据
	var generated_map := world_generator.generate(target_blueprint)
	var rooms_value: Variant = generated_map.get("rooms")
	var doors_value: Variant = generated_map.get("doors")
	if not rooms_value is Dictionary or not doors_value is Dictionary:
		return _abort_map_initialization("地图生成结果缺少 rooms 或 doors 字典。")
	var rooms: Dictionary = rooms_value
	var doors: Dictionary = doors_value
	if rooms.is_empty() or not rooms.get(Vector2.ZERO) is RoomData:
		return _abort_map_initialization("地图生成结果缺少初始房间。")
	print("WorldManager ： 地图数据生成完成，房间：%d，门：%d。" % [rooms.size(), doors.size()])

	# 2. 分发数据给两个 Set 节点进行实体装配
	if not room_set.build_rooms(generated_map):
		return _abort_map_initialization("房间组装失败。")
	if not door_set.build_doors(generated_map):
		return _abort_map_initialization("门组装失败。")

	# 3. 设置初始房间与状态
	mapdata = generated_map
	if not enter_explore_mode():
		return _abort_map_initialization("探索表现状态切换失败。")
	print("WorldManager ： 地图初始化完成，已进入 EXPLORE。")
	return true


# 装配失败时撤下本次实例并保留 INIT，供调用者读取失败结果。
func _abort_map_initialization(reason: String) -> bool:
	if is_instance_valid(room_set):
		room_set.clear_rooms()
	if is_instance_valid(door_set):
		door_set.clear_doors()
	if is_instance_valid(player_visual):
		player_visual.suspend_after_world_initialization_failure()
	mapdata = {}
	current_room_coords = Vector2.ZERO
	current_state = WorldState.INIT
	push_error("WorldManager ： 地图初始化中止：%s" % reason)
	return false


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
	if not player_visual.change_mode("preparing_battle"):
		push_error("[WorldManager] 无法切换到战斗准备表现状态。")
		return false
	if approach_target == null:
		push_warning("[WorldManager] 缺少可选敌人接近目标；跳过运镜并进入已启动的战斗。")
		if not player_visual.change_mode("battle"):
			return false
		_set_world_state(WorldState.BATTLE)
		return true
	if not player_visual.can_start_encounter_approach(approach_target):
		push_error("[WorldManager] 玩家接近运镜依赖无效。")
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


# 清理当前房间的敌人，并在成功后回到探索模式。
func finish_battle() -> bool:
	var room_data: RoomData = mapdata.get("rooms", {}).get(current_room_coords)
	var room_instance: BattleRoom = room_set.get_room_instance(room_data) if room_set else null
	if room_instance == null or not room_data.has_enemies:
		push_error("[WorldManager] 无法结束战斗：当前房间或敌人已失效。")
		return false
	room_instance.clear_enemies()
	if not enter_explore_mode():
		return false
	print("[WorldManager] 战斗胜利！")
	return true


# 将已执行的敌方攻击交给当前房间的模型表现节点。
func show_enemy_attack_feedback(source_id: String, on_completed: Callable = Callable()) -> bool:
	var visual := _get_current_enemy_visual(source_id)
	if visual != null and is_instance_valid(player_visual) and is_instance_valid(player_visual.player):
		return visual.play_attack_lunge(player_visual.player.global_position, on_completed)
	return false


# 仅在实际敌方扣血后调用房间模型的受击接口。
func show_enemy_hit_feedback(target_id: String, on_completed: Callable = Callable()) -> bool:
	var visual := _get_current_enemy_visual(target_id)
	if visual != null:
		return visual.play_hit_reaction(on_completed)
	return false


# 玩家受伤表现由 PlayerVisualManager 持有相机与覆盖层。
func show_player_damage_feedback(on_completed: Callable = Callable()) -> bool:
	if is_instance_valid(player_visual) and current_state == WorldState.BATTLE:
		return player_visual.show_damage_feedback(on_completed)
	return false


# 取消本房间与玩家在途的战斗占位效果，不修改战斗实体。
func cancel_combat_feedback() -> void:
	if is_instance_valid(player_visual):
		player_visual.cancel_damage_feedback()
	if room_set == null:
		return
	var room_data: RoomData = mapdata.get("rooms", {}).get(current_room_coords)
	var room_instance := room_set.get_room_instance(room_data)
	if room_instance != null:
		var visual := room_instance.get_enemy_visual()
		if visual != null:
			visual.cancel_feedback()


# 根据当前 RoomData 和敌人 ID 定位其可选视觉模型。
func _get_current_enemy_visual(entity_id: String) -> EnemyVisual:
	if current_state != WorldState.BATTLE or room_set == null:
		return null
	var room_data: RoomData = mapdata.get("rooms", {}).get(current_room_coords)
	if room_data == null or not room_data.has_enemies or entity_id != "enemy_%d" % room_data.enemy_id:
		return null
	var room_instance := room_set.get_room_instance(room_data)
	return room_instance.get_enemy_visual() if room_instance != null else null


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
