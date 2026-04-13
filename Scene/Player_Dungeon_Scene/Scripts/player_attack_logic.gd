extends Node


@onready var player = owner
@export var attack_range: float#攻击距离
@export var attack_angle_width = PI/2.0#攻击角度范围
var points_count = 12#扇形范围的顶点


const support_range: float = 80

var last_direction: Vector2 = Vector2.RIGHT#记录玩家静止前的朝向
#攻击输入
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("Attack"):
		attack()
		print(last_direction)
		return

#攻击判定
func attack():
	var space_state = player.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(points_count + 1):
		var angle = -attack_angle_width/2 + (attack_angle_width * i/ points_count)
		points.append(Vector2.from_angle(angle) * attack_range)
	
	var shape = ConvexPolygonShape2D.new()
	shape.points = points
	query.shape = shape
	
	var transform = Transform2D(last_direction.angle(), player.global_position)
	query.transform = transform
	
	draw_debug_attack_range(transform, shape)
	
	#制作敌人时请将Layer层设置为3
	query.collision_mask = 4
	
	#返回攻击范围内敌人的列表
	var result = space_state.intersect_shape(query)
	var hit_enemies = {"enemies":[]}
	var hit_enemies_target = {}
	hit_enemies_target.clear()
	
	for hit in result:
		var target = hit.collider
		if target.is_in_group("Enemies"):
			hit_enemies_target[target] = true
			var info_node = target.get_node_or_null("Information")
			if info_node:
				hit_enemies["enemies"].append(info_node.BattleID)
				
	var support_enemies = support_check(hit_enemies_target)
	print(hit_enemies)
	print("支援的敌人：",support_enemies)
	if hit_enemies["enemies"].is_empty():
		return
	else:
		get_tree().change_scene_to_file("res://Scene/Battle_scene/Battlescene.tscn")
		EventBus.enter_battle_scene.emit()
	pass

#支援范围检测
func support_check(hit_enemies_target: Dictionary) -> Dictionary:
	var space_state = player.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var shape = CircleShape2D.new()
	shape.radius = support_range
	query.shape = shape
	
	var transform = Transform2D(0, player.global_position)
	query.transform = transform
	
	draw_debug_support(transform, shape)
	
	query.collision_mask = 4
	
	var result = space_state.intersect_shape(query)
	var support_enemies = {"enemies":[]}
	var support_enemies_target = {}
	support_enemies_target.clear()
	
	print(result)
	
	for support in result:
		var target = support.collider
		if target.is_in_group("Enemies"):
			if not hit_enemies_target.has(target) and not support_enemies_target.has(target):
				support_enemies_target[target] = true
				var info_node = target.get_node("Information")
				support_enemies["enemies"].append(info_node.BattleID)
	return support_enemies
	pass

#敌人朝向
func enemy_face()-> bool:
	return true


# 在你的玩家脚本中添加这个辅助函数
func draw_debug_attack_range(transform: Transform2D, shape: ConvexPolygonShape2D):
	var line = $Line2D
	#line.global_position = Vector2(200,200)
	line.global_transform = transform
	line.width = 2.0
	line.default_color = Color.RED
	line.z_index = 100
	
	var points = []
	points = shape.points
	
	var draw_points = PackedVector2Array(points)
	if draw_points.size() > 0:
		draw_points.append(draw_points[0]) 
	
	line.points = draw_points
	line.visible = true
	
	# 0.5秒后消失
	await get_tree().create_timer(0.5).timeout
	line.visible = false


func draw_debug_support(transform: Transform2D, shape:CircleShape2D):
	var line = $Line2D2
	#line.global_position = Vector2(200,200)
	line.global_transform = transform
	line.width = 2.0
	line.default_color = Color.RED
	line.z_index = 100
	
	var radius = shape.radius
	var segments = 32 # 圆的平滑度，点越多越圆
	
	# 生成圆周上的点
	for i in range(segments + 1):
		var angle = float(i) / segments * TAU # TAU 是 2 * PI
		var point = Vector2(cos(angle), sin(angle)) * radius
		line.add_point(point)
	
	# 设置 Line2D 的位置，使其跟随 transform
	# 注意：Line2D 的 points 是相对于自身的，所以设置 global_position 即可
	line.global_position = transform.origin
	line.visible = true
	
	await get_tree().create_timer(0.5).timeout
	line.visible = false
