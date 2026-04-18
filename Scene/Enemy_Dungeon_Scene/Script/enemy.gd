#敌人管理器
class_name DungeonEnemy
extends Node

@onready var enemy: CharacterBody2D = owner
var tilemap: TileMapLayer
@onready var detection: Area2D = $Detection
@export var ray: RayCast2D

var last_direction: Vector2 = Vector2.DOWN

var player_target: Node2D
var target_in_area: Node2D


func _physics_process(delta: float) -> void:
	if enemy.velocity.length() > 0.1:
		last_direction = enemy.velocity.normalized()
	
	if target_in_area:
		if is_player_in_fov(target_in_area):
			ray.enabled = true
			ray.target_position = ray.to_local(target_in_area.global_position)
			ray.force_raycast_update()
			
			if ray.is_colliding() and ray.get_collider() == target_in_area:
				player_target = target_in_area
			else:
				player_target = null
		else:
			player_target = null
	else:
		player_target = null


func get_detected_player() -> CharacterBody2D:
	return player_target


#func get_patrol_target()-> Vector2:
	#if my_node == null:
		#return enemy.global_position
	#
	#var room = my_node.room
	#var target_x = randf_range(room.position.x, room.end.x)
	#var target_y = randf_range(room.position.y, room.end.y)
	#var target_pos = Vector2i(target_x, target_y)
	#var world_target_pos = tilemap.local_to_map(target_pos)
	#return world_target_pos


func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		target_in_area = body


func _on_detection_body_exited(body: Node2D) -> void:
	if body == target_in_area:
		target_in_area = null
		player_target = null
	pass

#检查玩家是否再敌人的fov内
func is_player_in_fov(player: Node2D) -> bool:
	var to_player = (player.global_position - enemy.global_position).normalized()
	return last_direction.dot(to_player) > 0.77#点积计算判断
