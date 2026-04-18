class_name GungeonEnemeyMoveMent
extends Node

var enemy = owner
var velocity: Vector2 = Vector2.ZERO
var speed: float = 200

#怪物寻路
func move_to(target_position: Vector2):
	var direction = (target_position - enemy.globla_position).normalized()
	enemy.velocity = enemy.velocity.lerp(direction * speed, 0.1)
	enemy.move_and_slide()
	pass

#怪物停止移动
func move_stop():
	velocity = Vector2.ZERO
