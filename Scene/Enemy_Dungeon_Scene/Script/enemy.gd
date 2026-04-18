#敌人管理器
extends Node

@onready var enemy: CharacterBody2D = $"."
@onready var my_info: DungeonEnemyInfo = $Information
@export var animated: AnimatedSprite2D
@onready var detection: Area2D = $Detection
@export var ray: RayCast2D
@export var movement: GungeonEnemeyMoveMent

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

#怪物获取自身房间的方法
func get_my_room() -> BSPNode:
	return my_info.MyNode

#怪物获取自身所在瓦片地图的方法
func get_my_mapInfo() -> MapInfo:
	return my_info.map_info

#动画播放
func play_animation(anim_name: String):
	animated.play(anim_name)


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
