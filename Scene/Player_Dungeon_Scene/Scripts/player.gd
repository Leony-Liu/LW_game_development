extends CharacterBody2D


const SPEED = 300.0


func _physics_process(delta: float) -> void:
	var direction = Input.get_axis("Left", "Right")
	velocity.x = direction * SPEED
	var updown = Input.get_axis("Up", "Down")
	velocity.y = updown * SPEED

	move_and_slide()
