class_name PlayerVisualManager
extends Node3D


signal validate_move_requested(target_grid: Vector2i, facing: String)
signal room_entered(grid_pos: Vector2i)

@export var player_controller: PlayerController # 向下依赖注入
@export var player_camera: Node3D 
@export var room_size: float = 10.0 

const FACING_ANGLES = {"N": 0.0, "E": -90.0, "S": -180.0, "W": 90.0}


# 信号连接
func _ready() -> void:
	player_controller.intent_to_move.connect(_on_controller_intent_move)
	player_controller.intent_to_turn.connect(_on_controller_intent_turn)

#region 信号交接

func _on_controller_intent_move(target_grid: Vector2i, facing: String) -> void:
	validate_move_requested.emit(target_grid, facing)

func _on_controller_intent_turn(target_facing: String) -> void:
	# 旋转无需验证地图，直接执行，完成后通知下级更新状态
	execute_turn(target_facing)
#endregion

# --- 接收上级 (WorldManager) 的指令并向下管理 (Call Down) ---
func spawn_player(grid_pos: Vector2i, facing: String) -> void:
	player_camera.position = Vector3(grid_pos.x * room_size, 0, grid_pos.y * room_size)
	player_camera.rotation_degrees.y = FACING_ANGLES[facing]
	player_controller.setup(grid_pos, facing)

func execute_move(target_grid: Vector2i) -> void:
	var target_pos = Vector3(target_grid.x * room_size, 0, target_grid.y * room_size)
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player_camera, "position", target_pos, 0.4)
	
	await tween.finished
	# 动画结束，向下通知 Controller 同步最终数据并解锁
	player_controller.update_state_and_unlock(target_grid, player_controller.current_facing)
	# 向上通知 Manager 房间抵达，可以查水表了
	room_entered.emit(target_grid)

func execute_turn(target_facing: String) -> void:
	var target_rot_y = FACING_ANGLES[target_facing]
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(player_camera, "rotation_degrees:y", target_rot_y, 0.3).as_relative().as_relative()
	
	await tween.finished
	player_controller.update_state_and_unlock(player_controller.current_grid, target_facing)

# 如果 Manager 判定撞墙，调用此方法解开底层的锁
func cancel_action() -> void:
	player_controller.set_lock(false)

# 遭遇敌人时，由 Manager 调用的锁
func lock_player_input(locked: bool) -> void:
	player_controller.set_lock(locked)
