extends Node

signal BattleStart

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
	
	var spawn_pos = player.global_position + (last_direction * (attack_range))
	var angle = last_direction.angle()
	query.transform = Transform2D(angle, space_state)
	
	#制作敌人时请将Layer层设置为3
	query.collision_mask = 3
	
	#返回攻击范围内敌人的列表
	var result = space_state.instersect_shape(query)
	
	pass

#敌人朝向
func enemy_face()-> bool:
	return true
