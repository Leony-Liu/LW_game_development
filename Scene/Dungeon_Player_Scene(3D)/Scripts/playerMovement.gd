extends Node

@onready var anim_tree: AnimationTree = $"../AnimationTree"
@onready var anim_state = anim_tree.get("parameters/playback")

@export_group("Movement")
@onready var player: CharacterBody3D = owner
@export var speed: float = 1.0#移动速度
@export var acceleration = 20.0#加速度
@export var rotation_speed: float = 10.0#转向速度
@onready var player_point: Node3D = $"../PlayerPoint"

var last_move_direction := Vector3.BACK

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
	
	player.velocity = player.velocity.move_toward(move_direction * speed, acceleration * delta)#控制角色平滑加速
	player.move_and_slide()
	
	if move_direction.length() > 0.2:
		last_move_direction = move_direction
	
	var target_angle := Vector3.BACK.signed_angle_to(last_move_direction, Vector3.UP)#Vector3.BACK为基准向量，signed_angle_to决定向左还是向右转
	player_point.global_rotation.y = lerp_angle(player_point.global_rotation.y, target_angle, rotation_speed * delta)#控制角色平滑转向
	
	if player.velocity.length() > 0.0:
		anim_state.travel("Walk")
	else:
		anim_state.travel("Idle")
