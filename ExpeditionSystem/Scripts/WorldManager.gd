class_name WorldManager
extends Node

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

# TODO 暂定房间数量
var default_room_count: int = 10

var current_state: WorldState = WorldState.INIT
var mapdata: Dictionary = {}
var current_room_coords: Vector2 = Vector2.ZERO


func _ready() -> void:
	# 监听 DoorSet 的开门中继信号
	if door_set:
		door_set.door_opened_relay.connect(_on_door_opened)

	# 启动时执行初始化生成
	init_map(default_room_count)


## 生成地图
func init_map(room_count: int) -> void:
	current_state = WorldState.INIT

	if not world_generator or not room_set or not door_set:
		push_error("WorldManager: 缺少生成器或 Set 节点引用！")
		return

	# 1. 驱动算法生成地图蓝本数据
	mapdata = world_generator.generate(room_count)

	# 2. 分发数据给两个 Set 节点进行实体装配
	room_set.build_rooms(mapdata)
	door_set.build_doors(mapdata)

	# 3. 设置初始房间与状态
	current_room_coords = Vector2.ZERO
	enter_explore_mode()

## 世界阶段切换
# 进入探索模式
func enter_explore_mode() -> void:
	current_state = WorldState.EXPLORE
	if player_visual:
		player_visual.change_mode("explore")
	print("[WorldManager] 进入探索模式")


# 进入战斗准备模式（运镜、锁定玩家控制、播入场动效）
func enter_preparing_battle_mode(target_room: RoomData) -> void:
	current_state = WorldState.PREPARING_BATTLE
	print("[WorldManager] 发现敌人！进入准备战斗模式: 房间 ", target_room.room_position)

	# 1. 临时锁定玩家控制，防止准备阶段走动
	if player_visual and player_visual.player:
		player_visual.player.set_active(false)

	# 2. 模拟准备阶段的运镜与动画过渡（此处用定时器演示，后续可接入运镜动画轨道）
	var prep_timer := get_tree().create_timer(1.2)
	prep_timer.timeout.connect(enter_battle_mode)


# 进入正式战斗模式
func enter_battle_mode() -> void:
	current_state = WorldState.BATTLE
	print("[WorldManager] 镜头就绪，进入正式战斗模式！")
	
	# 恢复控制或移交战斗系统管理
	if player_visual and player_visual.player:
		player_visual.player.set_active(true)
	
	# 此处可发送信号唤醒同级子系统 BattleSystem:
	# var battle_system = get_node_or_null("../BattleSystem")


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
			enter_preparing_battle_mode(target_room)
