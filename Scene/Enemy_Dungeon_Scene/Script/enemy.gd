class_name DungeonEnemy
extends Node



signal im_patrol()

@onready var enemy: CharacterBody2D = owner
@export var speed: float = 200
var tilemap: TileMapLayer

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
	var world_target_pos = tilemap.local_to_map(target_pos)
	return world_target_pos

func idel():
	enemy.velocity = Vector2.ZERO
	pass


func pursue():
	pass
