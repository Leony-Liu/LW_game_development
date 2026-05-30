extends Node
class_name DungeonPlayerAttackComponent

@export_group("StateMachine")
@export var state_machine: DungeonPlayerStateMachine

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("Attack"):
		state_machine.change_state("hook")
	pass
