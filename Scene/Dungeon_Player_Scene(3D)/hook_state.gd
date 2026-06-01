extends DungeonPlayerState

@export var anim_tree: AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/StateMachine/playback")

func enter():
	super.enter()
	print("玩家攻击")
	can_move = false
	player.velocity = Vector3.ZERO
	anim_tree["parameters/OneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE


func update(delta):
	super.update(delta)


func on_hook_anim_finished():
	machine.change_state("idle")
