extends Node
class_name DungeonPlayerState

var machine: DungeonPlayerStateMachine
var player: Player = owner
var can_move: bool = true#判断当前状态类型是否允许移动

func enter():
	pass

func exit(): 
	pass

func update(delta): 
	pass

func physics_update(delta): 
	pass
