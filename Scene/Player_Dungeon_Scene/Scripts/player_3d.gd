extends CharacterBody3D

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")

func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("Left", "Right", "Up", "Down")
	
	if input_dir.length() > 0:
		anim_state.travel("Walk")
	else:
		anim_state.travel("Idle")
