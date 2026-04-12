extends Node


@onready var player = owner
@export var attack_range: float#攻击距离
@export var attack_width: float#攻击范围

var last_direction: Vector2 = Vector2.RIGHT#记录玩家静止前的朝向
#攻击输入
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("Attack"):
		attack()
		return

#攻击判定
func attack():
	var space_state = player.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	#设置攻击判定区域
	var shape = RectangleShape2D.new()
	shape.size = Vector2(attack_range, attack_width)
	query.shape = shape
	
	var transform = Transform2D(0, player.global_position + last_direction * (attack_range/2))
	query.transform = transform
	
	draw_debug_attack_range(transform, shape)
	
	#制作敌人时请将Layer层设置为3
	query.collision_mask = 4
	
	#返回攻击范围内敌人的列表
	var result = space_state.intersect_shape(query)
	var hit_enemies = {}
	for hit in result:
		var target = hit.collider
		var enemy_node = target.get_parent()
		print(enemy_node.name)
		if target.is_in_group("Enemies"):
			print("检测到打击的敌人")
			var info_node = enemy_node.get_node_or_null("Information")
			if info_node:
				hit_enemies[enemy_node] = info_node.ID
	print(hit_enemies)
	print(result)
	EventBus.enter_battle_scene.emit()
	
	pass

#敌人朝向
func enemy_face()-> bool:
	return true


# 在你的玩家脚本中添加这个辅助函数
func draw_debug_attack_range(transform: Transform2D, shape: Shape2D):
	var line = $Line2D
	#line.global_position = Vector2(200,200)
	line.global_transform = transform
	line.width = 2.0
	line.default_color = Color.RED
	line.z_index = 100
	
	# 画一个矩形框 (假设 shape 是 RectangleShape2D)
	var s = shape.size
	line.points = PackedVector2Array([
		Vector2(-s.x/2, -s.y/2), 
		Vector2(s.x/2, -s.y/2), 
		Vector2(s.x/2, s.y/2), 
		Vector2(-s.x/2, s.y/2), 
		Vector2(-s.x/2, -s.y/2)
	])
	
	line.visible = true
	
	# 0.5秒后消失
	await get_tree().create_timer(0.5).timeout
	line.visible = false
