class_name WorldManager
extends Node

# --- 向上级汇报的信号 ---
signal combat_triggered(enemy_id: int, room_grid_pos: Vector2i)
signal world_generated(start_grid: Vector2i)

# --- 向下调用的子模块引用 ---
@export var room_set: RoomSet
@export var player_visual_manager: PlayerVisualManager
var world_generator: WorldGenerator # 若未在检查器挂载，脚本内会自动通过 RefCounted 实例化
var world_save_module: WorldSaveModule

@export_group("调试与配置")
@export var auto_generate_on_ready: bool = true 
@export var default_room_count: int = 10

var _current_active_room: Vector2i = Vector2i.ZERO
var _map_grid: Dictionary = {} # 格式: Dictionary[Vector2i, RoomData]

func _ready() -> void:

	# 监听视觉层向上汇报的意图与步入事件
	if player_visual_manager:
		player_visual_manager.validate_move_requested.connect(_on_validate_move_requested)
		player_visual_manager.room_entered.connect(_check_room_enemy)

	# 调试模式下直接触发生成
	if auto_generate_on_ready:
		initialize_world(default_room_count)

# --- 核心流程：地图生成与世界初始化 ---
func initialize_world(target_room_count: int = 10) -> void:
	print("[WorldManager] 开始生成世界地图，目标房间数: ", target_room_count)
	
	# 1. 获取生成种子（优先读取存档模块，无存档则随机）
	var rng_seed: int = randi()
	if world_save_module:
		rng_seed = world_save_module.get_or_create_seed()
	
	# 2. 向下调用 WorldGenerator：执行纯数学/数据拓扑推演
	_map_grid = world_generator.generate_map_data(rng_seed, target_room_count)
	var start_pos: Vector2i = world_generator.get_start_room_pos()
	_current_active_room = start_pos
	
	# 3. 向下调用 RoomSet：接收数据并在 3D 空间中实例化房间实体
	if room_set:
		room_set.build_rooms(_map_grid)
	
	# 4. 向下调用 PlayerVisualManager：将玩家放置在出生点正中心
	if player_visual_manager:
		player_visual_manager.spawn_player(start_pos, "N")
	
	# 5. 向下调用 WorldSaveModule：将初始状态写入存档中枢
	if world_save_module:
		world_save_module.save_world_state(_map_grid)
	
	# 6. 向上发送生成完毕信号
	world_generated.emit(start_pos)
	print("[WorldManager] 地图生成与实体装配完毕，出生点位于: ", start_pos)

# 玩家房间切换判断
func _on_validate_move_requested(target_grid: Vector2i, facing: String) -> void:
	# 查询当前所在房间数据，确认对应朝向是否有门
	var current_room: RoomData = _map_grid.get(_current_active_room)
	if current_room and current_room.doors.has(facing):
		# 合法：命令视觉管理器执行平滑移动
		player_visual_manager.execute_move(target_grid)
	else:
		# 撞墙：命令视觉管理器取消动作并解锁底层输入
		player_visual_manager.cancel_action()

func _check_room_enemy(grid_pos: Vector2i) -> void:
	_current_active_room = grid_pos
	var room_data: RoomData = _map_grid.get(grid_pos)
	if not room_data:
		return
	
	# 如果房间内有未被消灭的敌人，原地锁定输入并向上唤起战斗系统
	if room_data.has_enemy and not room_data.is_cleared:
		player_visual_manager.lock_player_input(true)
		combat_triggered.emit(room_data.enemy_id, grid_pos)

# --- 战斗结算响应 ---
func battle_finished(is_victory: bool) -> void:
	if is_victory:
		print("[WorldManager] 战斗胜利，清除房间怪物并持久化状态。")
		var room_data: RoomData = _map_grid.get(_current_active_room)
		if room_data:
			room_data.is_cleared = true
			if room_set:
				room_set.clear_enemy_visual_in_room(_current_active_room)
		
		if world_save_module:
			world_save_module.save_world_state(_map_grid)
			
		# 修正原代码接口调用错误：通知视觉管理器解锁底层按键
		if player_visual_manager:
			player_visual_manager.lock_player_input(false)
