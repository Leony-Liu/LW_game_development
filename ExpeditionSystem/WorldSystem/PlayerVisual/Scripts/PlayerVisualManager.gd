## 管理探索、战斗准备、战斗与调试模式的玩家控制及相机归属。
## 世界状态只通过此入口切换表现，不直接分散修改子节点。
class_name PlayerVisualManager
extends Node3D

signal encounter_approach_finished(transition_id: int, succeeded: bool)

@export_group("子节点引用")
@export var player: PlayerController
@export var head: HeadController
@export var bob_mount: Node3D
@export var player_camera: Camera3D
@export var debug_free_camera: Camera3D

@export_group("遇敌接近运镜")
## 在此组调整原型运镜速度、停距、转向与到位停顿。
@export_range(0.1, 10.0, 0.1) var approach_speed: float = 2.2
@export_range(0.5, 5.0, 0.1) var approach_stop_distance: float = 2.0
@export_range(0.1, 12.0, 0.1) var approach_turn_speed: float = 5.0
@export_range(0.0, 2.0, 0.05) var approach_settle_time: float = 0.15
@export_range(1.0, 30.0, 0.5) var approach_max_duration: float = 8.0

var current_mode: String = "explore"
var _active_approach_id: int = -1

# 初始化运动中继并进入探索表现模式。
func _ready() -> void:
	# 监听 Player 的运动信号
	if player and player.has_signal("movement_state_changed"):
		player.movement_state_changed.connect(_on_player_movement_changed)
	if player and not player.cinematic_approach_finished.is_connected(
		_on_cinematic_approach_finished
	):
		player.cinematic_approach_finished.connect(_on_cinematic_approach_finished)
	change_mode("explore")

## 切换控制、相机与鼠标模式；未知模式会明确失败。
func change_mode(mode: String) -> bool:
	var next_mode := mode.to_lower()

	match next_mode:
		"explore", "探索":
			cancel_encounter_approach()
			_set_exploration_controls_active(true)
			_set_player_camera_active(true)
			_set_debug_active(false)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			next_mode = "explore"

		"preparing_battle", "battle":
			if next_mode == "battle":
				cancel_encounter_approach()
			_set_exploration_controls_active(false)
			_set_player_camera_active(true)
			_set_debug_active(false)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		"debug", "调试":
			cancel_encounter_approach()
			# 同步自由相机的世界坐标与视角至当前玩家眼睛所在位置
			if player_camera and debug_free_camera:
				debug_free_camera.global_transform = player_camera.global_transform

			_set_exploration_controls_active(false)
			_set_player_camera_active(false)
			_set_debug_active(true)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			next_mode = "debug"

		_:
			push_error("PlayerVisualManager: 未知控制模式 '%s'。" % mode)
			return false

	current_mode = next_mode
	return true


# 预检当前玩家、相机与目标能否启动遇敌接近。
func can_start_encounter_approach(target: Node3D) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(head):
		return false
	if not is_instance_valid(player_camera) or not player_camera.is_inside_tree():
		return false
	if not is_instance_valid(target) or not target.is_inside_tree():
		return false
	return not player.is_cinematic_approach_active()


# 用真实玩家与当前第一人称相机启动一次带身份的自动接近。
func start_encounter_approach(target: Node3D, transition_id: int) -> bool:
	if current_mode != "preparing_battle":
		return false
	if not can_start_encounter_approach(target) or not player_camera.current:
		return false
	if not player.start_cinematic_approach(
		target,
		head,
		transition_id,
		approach_speed,
		approach_stop_distance,
		approach_turn_speed,
		approach_settle_time,
		approach_max_duration
	):
		return false
	_active_approach_id = transition_id
	return true


# 取消当前运镜并使后续旧回调失效。
func cancel_encounter_approach(transition_id: int = -1) -> bool:
	if transition_id >= 0 and transition_id != _active_approach_id:
		return false
	var cancelled := false
	if is_instance_valid(player):
		cancelled = player.cancel_cinematic_approach(transition_id)
	_active_approach_id = -1
	return cancelled

# 统一启停探索移动和视角输入。
func _set_exploration_controls_active(active: bool) -> void:
	if player and player.has_method("set_active"):
		player.set_active(active)
	if head and head.has_method("set_active"):
		head.set_active(active)


# 切换玩家相机的当前状态。
func _set_player_camera_active(active: bool) -> void:
	if player_camera:
		player_camera.current = active


# 切换调试自由相机。
func _set_debug_active(active: bool) -> void:
	if debug_free_camera:
		debug_free_camera.current = active
		if debug_free_camera.has_method("set_active"):
			debug_free_camera.set_active(active)

## 运动中继：把物理层的数值传递给表现层。
func _on_player_movement_changed(delta: float, speed: float, is_on_floor: bool, is_sprinting: bool) -> void:
	if bob_mount and bob_mount.has_method("apply_bob"):
		bob_mount.apply_bob(delta, speed, is_on_floor, is_sprinting)


# 只中继当前运镜的完成结果，旧身份不会推进 World。
func _on_cinematic_approach_finished(approach_id: int, succeeded: bool) -> void:
	if approach_id != _active_approach_id:
		return
	_active_approach_id = -1
	encounter_approach_finished.emit(approach_id, succeeded)
