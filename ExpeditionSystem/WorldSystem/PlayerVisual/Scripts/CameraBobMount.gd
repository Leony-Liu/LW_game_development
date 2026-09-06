class_name CameraBobMount
extends Node3D

@export var walk_bob_freq: float = 10.0
@export var walk_bob_amp: float = 0.04
@export var sprint_bob_freq: float = 14.0
@export var sprint_bob_amp: float = 0.08

var bob_timer: float = 0.0

func apply_bob(delta: float, speed: float, on_floor: bool, is_sprinting: bool) -> void:
	if on_floor and speed > 0.2:
		var freq := sprint_bob_freq if is_sprinting else walk_bob_freq
		var amp := sprint_bob_amp if is_sprinting else walk_bob_amp
		
		bob_timer += delta * freq
		
		var target_y := sin(bob_timer) * amp
		var target_x := cos(bob_timer * 0.5) * (amp * 0.6)
		
		position.x = lerp(position.x, target_x, delta * 12.0)
		position.y = lerp(position.y, target_y, delta * 12.0)
	else:
		bob_timer = 0.0
		position.x = lerp(position.x, 0.0, delta * 10.0)
		position.y = lerp(position.y, 0.0, delta * 10.0)
