class_name PlayerController
extends Node

# 向上汇报意图（不管谁听）
signal intent_to_move(target_grid: Vector2i, facing: String)
signal intent_to_turn(target_facing: String)

var current_grid: Vector2i
var current_facing: String
var is_locked: bool = false

const DIR_VECTORS = {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const TURN_RIGHT = {"N": "E", "E": "S", "S": "W", "W": "N"}
const TURN_LEFT = {"N": "W", "W": "S", "S": "E", "E": "N"}

# --- 接收上级指令 (Call Down) ---
func setup(start_grid: Vector2i, start_facing: String) -> void:
	current_grid = start_grid
	current_facing = start_facing
	is_locked = false

func update_state_and_unlock(new_grid: Vector2i, new_facing: String) -> void:
	current_grid = new_grid
	current_facing = new_facing
	is_locked = false

func set_lock(locked: bool) -> void:
	is_locked = locked

# 交互信号汇报
func _unhandled_input(event: InputEvent) -> void:
	if is_locked: return
	# 前进
	if event.is_action_pressed("move_forward"):
		is_locked = true # 先锁死，等上层回复
		var target = current_grid + DIR_VECTORS[current_facing]
		intent_to_move.emit(target, current_facing)
	# 转向
	elif event.is_action_pressed("turn_left"):
		is_locked = true
		intent_to_turn.emit(TURN_LEFT[current_facing])
	# 转向
	elif event.is_action_pressed("turn_right"):
		is_locked = true
		intent_to_turn.emit(TURN_RIGHT[current_facing])
