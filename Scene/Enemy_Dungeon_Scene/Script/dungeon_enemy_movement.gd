class_name GungeonEnemeyMoveMent
extends Node

var enemy: DungeonEnemy
var velocity: Vector2 = Vector2.ZERO
var speed: float = 200

var obstacle_coords: Dictionary
var wall_coords: Dictionary


func _ready() -> void:
	enemy = get_owner() as DungeonEnemy
	obstacle_coords = enemy.my_info.my_map_manager.

#怪物寻路
func move_to(target_position: Vector2):
	#获取所在tilemap
	var my_tilemap = enemy.get_my_tilemap()
	#将怪物自己的坐标转换为地图坐标
	var enemy_local_pos = my_tilemap.to_local(enemy.global_position)
	var enemy_grid_pos = my_tilemap.local_to_map(enemy_local_pos)
	#将目标坐标转换为地图坐标
	var target_local_pos = my_tilemap.to_local(target_position)
	var target_grid_pos = my_tilemap.local_to_map(target_local_pos)
	#计算怪物自身坐标周围的8个坐标
	#计算8个坐标里每个坐标到目标的距离，对比之后得出最优解
	#递归以上方法直到到达目标
	var direction = (target_position - enemy.globla_position).normalized()
	enemy.velocity = enemy.velocity.lerp(direction * speed, 0.1)
	enemy.move_and_slide()
	pass

#怪物停止移动
func move_stop():
	velocity = Vector2.ZERO


func A_star_way_find(find_coords: Vector2i):
	var tilemap = enemy.get_my_tilemap()
	var obstacle_coords = tilemap.get
	pass
