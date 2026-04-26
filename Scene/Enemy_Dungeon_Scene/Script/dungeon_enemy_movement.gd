class_name GungeonEnemeyMoveMent
extends Node

@export var enemy: CharacterBody2D
var velocity: Vector2 = Vector2.ZERO
var speed: float = 50

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

func set_target(target: Vector2):
	if current_target != target:
		current_target = target
		reset_path()

func reset_path():
	current_path.clear()
	path_index = 0

#怪物寻路
func move_to(delta:float, need_repath:bool = false):
	#获取所在tilemap
	var my_tilemap = my_map_info.basic_tilemap
	#将怪物自己的坐标转换为地图坐标
	var enemy_local_pos = my_tilemap.to_local(enemy.global_position)
	var enemy_grid_pos = my_tilemap.local_to_map(enemy_local_pos)
	#将目标坐标转换为地图坐标
	var target_local_pos = my_tilemap.to_local(current_target)
	var target_grid_pos = my_tilemap.local_to_map(target_local_pos)
	

	if current_path.is_empty():
		current_path = A_star_find_path(enemy_grid_pos, target_grid_pos, my_map_info.basic_tilemap)
		path_index = 0
	
	
	if path_index >= current_path.size():
		move_stop()
		return
		
	var to_pos = my_map_info.basic_tilemap.map_to_local(current_path[path_index])
	var direction = (to_pos - enemy.global_position).normalized()
	enemy.velocity = direction * speed
	enemy.move_and_slide()
	
	if enemy.global_position.distance_to(to_pos) < 5.0:
		path_index += 1
	#if current_path.is_empty():
		#move_stop()
		#print("路径列表为空")
	#else:
		#var to_pos = my_map_info.basic_tilemap.map_to_local(current_path[0])
		#var direction = (to_pos - enemy.global_position).normalized()
		#enemy.velocity = direction * speed
		#
		#if enemy.global_position.distance_to(to_pos) < 5.0:
			#path_index += 1
			#current_path.remove_at(0)
	#print("怪物试图走动")
	pass

#怪物停止移动
func move_stop():
	enemy.velocity = Vector2.ZERO


func get_distance(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)

#寻路方法
func A_star_find_path(start: Vector2i, end: Vector2i, tile_map: TileMapLayer) -> Array[Vector2i]:
	var open_list: Array[PathNode] = []#开启列表：所有待检测节点
	var closed_list: Dictionary = {}#关闭列表：记录每个代价最小的节点
	
	#实例化初始节点
	var start_node = PathNode.new(start)
	start_node.g_cost = 0
	start_node.h_cost = get_distance(start, end)
	start_node.f_cost = start_node.h_cost##
	open_list.append(start_node)
	
	var max_iterations = 2000
	var iteration = 0
	while open_list.size() > 0:
		#安全阀
		iteration += 1
		if iteration > max_iterations:
			print("怪物寻路器：寻路超出最大计算步数，强行停止寻路")
			break
		#找到待检测列表中f_cost最小的路径节点
		#var current_node = open_list[0]
		#for node in open_list:
			#if node.f_cost < current_node.f_cost:
				#current_node = node
		open_list.sort_custom(func(a, b): return a.f_cost < b.f_cost)##
		var current_node = open_list.pop_front()##
		
		if current_node.position == end:
			return reconstruct_path(current_node)
		
		#open_list.erase(current_node)#在待评估列表中移除当前节点##
		closed_list[current_node.position] = true#把当前节点放进关闭列表
		
		for dir in check_directions:
			var neighbor_pos = current_node.position + dir
			
			if my_map_info.obstacle_cell.has(neighbor_pos) or my_map_info.wall_cell.has(neighbor_pos):
				continue
			if closed_list.has(neighbor_pos): continue
			
			var new_g_cost = current_node.g_cost + 1
			var neighbor_node = find_node_in_list(open_list, neighbor_pos)
			if neighbor_node == null or new_g_cost < neighbor_node.g_cost:
				if neighbor_node == null:
					neighbor_node = PathNode.new(neighbor_pos)
					open_list.append(neighbor_node)
				
				neighbor_node.parent = current_node
				neighbor_node.g_cost = new_g_cost
				neighbor_node.h_cost = get_distance(neighbor_pos, end)
				neighbor_node.f_cost = neighbor_node.g_cost + neighbor_node.h_cost
				
	return []

#重终点回溯到起点
func reconstruct_path(node: PathNode) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = node
	while current != null:
		path.append(current.position)
		current = current.parent#把现有节点的父节点赋值给current继续循环，直到没有父级说明两个点连上了
	path.reverse()#反转数组，使路径是由起点到终点的
	return path

#重列表中获取节点来判断当前坐标是不是全新未探索过的坐标
func find_node_in_list(list: Array[PathNode], pos: Vector2i) -> PathNode:
	for n in list:
		if n.position == pos:
			return n
	return null
