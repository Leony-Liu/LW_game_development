class_name GungeonEnemeyMoveMent
extends Node

@export var enemy: Enemy
var velocity: Vector2 = Vector2.ZERO
var speed: float = 50
@onready var navigation_agent_2d: NavigationAgent2D = $"../Navigation/NavigationAgent2D"

var my_map_info: MapInfo

#四向检查，后期根据需要可升级到八向
var check_directions = [
	Vector2i(1,0), Vector2i(-1,0),
Vector2i(0,1), Vector2i(0,-1), ]


var current_path: Array[Vector2i]
var path_index: int = 0
var current_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	my_map_info = enemy.get_my_mapInfo()

#怪物寻路
func move_to(target: Vector2):
	navigation_agent_2d.target_position = target
	if not navigation_agent_2d.is_navigation_finished():
		var direction = enemy.to_local(navigation_agent_2d.get_next_path_position()).normalized()
		navigation_agent_2d.set_velocity(direction * speed)
	pass

#怪物停止移动
func move_stop():
	enemy.velocity = Vector2.ZERO


func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	enemy.velocity = safe_velocity
	enemy.move_and_slide()
	pass # Replace with function body.
