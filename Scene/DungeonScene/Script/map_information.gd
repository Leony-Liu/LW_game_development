class_name MapInfo
extends Node

@export var map_manager: Node2D
var basic_tilemap: TileMapLayer
var obstacle_cell: Dictionary
var wall_cell: Dictionary


func get_data():
	basic_tilemap = get_parent().get_node("BasicTerrainLayer")
	obstacle_cell = map_manager.World_obstacle
	wall_cell = map_manager.World_wall
	pass
