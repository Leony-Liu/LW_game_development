extends CharacterBody2D

signal Direction_change(new_direction: Vector2)
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var SPEED = 300
@export var last_direction: Vector2

func _physics_process(delta: float) -> void:
	var direction = Vector2(Input.get_axis("Left", "Right"), Input.get_axis("Up", "Down"))

	if direction.length() > 0:
		animated_sprite.play("run")
		velocity = direction.normalized() * SPEED
		last_direction = direction.normalized()
		Direction_change.emit(last_direction)
	else:
		animated_sprite.play("idle")
		velocity = Vector2.ZERO
		
	if direction.x > 0:
		animated_sprite.flip_h = false
	if direction.x < 0:
		animated_sprite.flip_h = true
	
		
		
	move_and_slide()
