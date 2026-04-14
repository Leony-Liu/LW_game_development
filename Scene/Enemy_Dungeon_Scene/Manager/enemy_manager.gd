extends Node

enum enemy_condition{
	Idel,
	Patrol,
	Pursue
}

@export var move_logic: Node
@export var informations: Node

func _ready() -> void:
	move_logic.tilemap = informations.TileMapReference
	#print(move_logic.tilemap)
	
	pass
