class_name PlayerVisualManager
extends Node3D

@export_group("子节点引用")
@export var player: CharacterBody3D
@export var head: Node3D
@export var bob_mount: Node3D
@export var player_camera: Camera3D
@export var debug_free_camera: Camera3D

var current_mode: String = "explore"

func _ready() -> void:
	# 监听 Player 的运动信号
	if player and player.has_signal("movement_state_changed"):
		player.movement_state_changed.connect(_on_player_movement_changed)
	change_mode("explore")

## 切换控制模式
func change_mode(mode: String) -> void:
	current_mode = mode.to_lower()
	
	match current_mode:
		"explore", "探索":
			_set_explore_active(true)
			_set_debug_active(false)
			
		"debug", "调试":
			# 同步自由相机的世界坐标与视角至当前玩家眼睛所在位置
			if player_camera and debug_free_camera:
				debug_free_camera.global_transform = player_camera.global_transform
				
			_set_explore_active(false)
			_set_debug_active(true)

# 切换成探索
func _set_explore_active(active: bool) -> void:
	if player and player.has_method("set_active"):
		player.set_active(active)
	if head and head.has_method("set_active"):
		head.set_active(active)
	if player_camera:
		player_camera.current = active
# 切换成调试
func _set_debug_active(active: bool) -> void:
	if debug_free_camera:
		debug_free_camera.current = active
		if debug_free_camera.has_method("set_active"):
			debug_free_camera.set_active(active)

## 运动中继：把物理层的数值传递给表现层
func _on_player_movement_changed(delta: float, speed: float, is_on_floor: bool, is_sprinting: bool) -> void:
	if bob_mount and bob_mount.has_method("apply_bob"):
		bob_mount.apply_bob(delta, speed, is_on_floor, is_sprinting)
