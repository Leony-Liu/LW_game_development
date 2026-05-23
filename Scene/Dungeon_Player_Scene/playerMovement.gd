extends Node

@onready var anim_tree: AnimationTree = $"../AnimationTree"
@onready var anim_state = anim_tree.get("parameters/playback")

@export_group("Movement")
@onready var player: CharacterBody3D = owner
@export var speed: float = 1.0#移动速度
@export var rotation_speed: float = 10.0#转向速度
@onready var player_point: Node3D = $"../PlayerPoint"

@export_group("Camera")
@onready var camera_pivot: Node3D = %CameraPivot
@onready var camera: Camera3D = %Camera3D


func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("Left", "Right", "Up", "Down")#获取输入方向
	var forward = camera.global_basis.z#获取前进方向
	var right = camera.global_basis.x#获取向右方向
	var move_direction = forward * input_dir.y + right * input_dir.x
	move_direction.y = 0.0#确保人物前进方向不会向地里倾斜
	move_direction = move_direction.normalized()#向量归一化得到地面平面上的方向
	
	#if direction.length() > 0:
		#player.velocity.x = direction.x * speed
		#player.velocity.z = direction.z * speed
		#
		#var target_rotation = atan2(direction.x, direction.z)
		#player_point.rotation.y = lerp_angle(player_point.rotation.y, target_rotation, rotation_speed * delta)
		
		#anim_state.travel("Walk")
	#else:
		#player.velocity.x = move_toward(player.velocity.x, 0, speed)
		#player.velocity.z = move_toward(player.velocity.z, 0, speed)
		#
		#anim_state.travel("Idle")
	#
	#player.move_and_slide()
