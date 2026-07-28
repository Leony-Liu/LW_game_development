class_name TimelineAction
extends RefCounted


var sequence_id: int = 0
var action_id: StringName = &""
var actor: Node
var remaining_value: int = 100
var starting_value: int = 100
var display_name: String = ""
var icon: Texture2D
var payload: Dictionary = {}


func advance(amount: int) -> void:
	remaining_value -= amount


func is_ready() -> bool:
	return remaining_value <= 0
