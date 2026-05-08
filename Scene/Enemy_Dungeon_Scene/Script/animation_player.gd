extends AnimationPlayer

@export var enemy = owner as Enemy

func _process(delta: float) -> void:
	var dir = Vector2(enemy.velocity.x, enemy.velocity.y)
	if dir.x > 0:
		enemy.sprite.flip_h = false
	else:
		enemy.sprite.flip_h = true
