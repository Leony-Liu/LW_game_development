extends Node

@onready var anim_tree: AnimationTree = $"../AnimationTree"
@onready var anim_state = anim_tree.get("parameters/playback")

@onready var player: CharacterBody3D = owner
@export var speed: float = 1.0#移动速度
@export var rotation_speed: float = 10.0#转向速度
	
func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("Left", "Right", "Up", "Down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if direction.length() > 0:
		player.velocity.x = direction.x * speed
		player.velocity.z = direction.z * speed
		
		var target_rotation = atan2(direction.x, direction.z)
		player.rotation.y = lerp_angle(player.rotation.y, target_rotation, rotation_speed * delta)
		
		anim_state.travel("Walk")
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, speed)
		player.velocity.z = move_toward(player.velocity.z, 0, speed)
		
		anim_state.travel("Idle")
	
	player.move_and_slide()
