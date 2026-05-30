extends DungeonPlayerState

@export var anim_tree: AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")

func enter():
	super.enter()
	print("玩家攻击")
	can_move = false
	player.velocity = Vector3.ZERO
	anim_state.travel("Hook")


func update(delta):
	super.update(delta)
	if anim_state.get_current_node() == "Idle":
		machine.change_state("idle")
