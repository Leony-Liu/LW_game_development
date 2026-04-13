extends Node

@export var player_move_logic: CharacterBody2D
@export var player_attack_logic: Node


func signal_pipeline():
	player_move_logic.Direction_change.connect(_on_player_direction_change)


func _on_player_direction_change(new_direction: Vector2) -> void:
	player_attack_logic.last_direction = new_direction
