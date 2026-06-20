#地图管理器
#作用：用于管理地图场景的生成和跳转
extends Node
class_name MapManager

@export var player_scence: PackedScene

const TARGET_ROOM_COUNT = 15
@export var room_scene: PackedScene
@onready var room_container: Node3D = $"../RoomContainer"

var rooms: Dictionary = {}
var next_room_id: int = 0
var current_room_id: int = 0
var start_room_id: int = 0


func _ready() -> void:
	generate_map()
	connect_rooms()
	build_map()
	pass

func generate_map():
	rooms.clear()
	
	next_room_id = 0
	var start_room = create_room(Vector2i.ZERO)
	
	while rooms.size() < TARGET_ROOM_COUNT:
		var existing_room:RoomData = rooms.values().pick_random()
		var dirs = [
			Vector2i.LEFT,
			Vector2i.RIGHT,
			Vector2i.UP,
			Vector2i.DOWN
		]
		
		var dir = dirs.pick_random()
		var target_pos = existing_room.grid_pos + dir
		
		if get_room_by_position(target_pos):
			continue
			
		create_room(target_pos)
	pass

func create_room(pos: Vector2i):
	var room = RoomData.new()
	room.id = next_room_id
	room.grid_pos = pos
	rooms[room.id] = room
	next_room_id += 1
	return room

func get_room_by_position(pos:Vector2i):
	for room in rooms.values():
		if room.grid_pos == pos:
			return room
	return null
	pass

func connect_rooms():
	for room in rooms.values():
		var pos = room.grid_pos
		var left = get_room_by_position(pos + Vector2i.LEFT)
		var right = get_room_by_position(pos + Vector2i.RIGHT)
		var up = get_room_by_position(pos + Vector2i.UP)
		var down = get_room_by_position(pos + Vector2i.DOWN)
		if left:
			room.left_room = left.id
		if right:
			room.right_room = right.id
		if up:
			room.up_room = up.id
		if down:
			room.down_room = down.id
	pass

func build_map():
	for room_data in rooms.values():
		var room = room_scene.instantiate()
		room.room_data = room_data
		room_container.add_child(room)
		room.position = Vector3(room_data.grid_pos.x * 50,0,room_data.grid_pos.y * 50)
		
		set_room_doors(room, room_data)
	pass

func set_room_doors(room: Room, room_data: RoomData):
	if room_data.left_room != -1:
		room.get_node("Doors/DoorLeft").target_room_id =room_data.left_room
		room.get_node("Doors/DoorLeft").enter_side ="right"
	else:
		room.get_node("Doors/DoorLeft").queue_free()
	
	if room_data.right_room != -1:
		room.get_node("Doors/DoorRight").target_room_id = room_data.right_room
		room.get_node("Doors/DoorRight").enter_side = "left"
	else:
		room.get_node("Doors/DoorRight").queue_free()
	
	if room_data.up_room != -1:
		room.get_node("Doors/DoorUp").target_room_id = room_data.up_room
		room.get_node("Doors/DoorUp").enter_side = "down"
	else:
		room.get_node("Doors/DoorUp").queue_free()
	
	if room_data.down_room != -1:
		room.get_node("Doors/DoorDown").target_room_id = room_data.down_room
		room.get_node("Doors/DoorDown").enter_side = "up"
	else:
		room.get_node("Doors/DoorDown").queue_free()
	pass

func enter_door(door: Door):
	if door.target_room_id == -1:
		return
	change_room(door.target_room_id,door.enter_side)
	pass

func change_room(target_room_id: int, enter_side: String):
	current_room_id = target_room_id
	var target_room = null
	for room in room_container.get_children():
		if room.room_data.id == target_room_id:
			target_room = room
			break
			
	if target_room == null:
		return
		
	var player =get_tree().get_first_node_in_group("Player")
	player.global_position = target_room.get_spawn_position(enter_side)
	pass
