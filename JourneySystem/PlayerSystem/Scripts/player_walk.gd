extends DungeonPlayerState

@export var anim_tree: AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/StateMachine/playback")

func enter():
	super.enter()
	print("玩家进入行走状态")
	anim_state.travel("Walk")

func physics_update(delta):
	super.physics_update(delta)
	if player.velocity.length() <= 0.2:
		machine.change_state("idle")
