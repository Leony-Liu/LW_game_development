extends Node
class_name enemy_dungeon

enum enemy_condition{
	Idel,
	Patrol,
	Pursue
}

@onready var enemy: CharacterBody2D = owner
@onready var nav_agent: NavigationAgent2D = enemy.get_node("NavigationAgent2D")
@export var speed: float = 200

var my_node: BSPNode#怪物所属房间

func _physics_process(delta: float) -> void:
	pass


func patrol():
	
	pass

func get_patrol_target()-> Vector2:
	if my_node == null:
		return enemy.global_position
	
	var room = my_node.room
	var target_x = randf_range(room.position.x, room.end.x)
	var target_y = randf_range(room.position.y, room.end.y)
	var target_pos = Vector2i(target_x, target_y)
	return Vector2(0, 0)

func idel():
	enemy.velocity = Vector2.ZERO
	pass


func pursue():
	pass
