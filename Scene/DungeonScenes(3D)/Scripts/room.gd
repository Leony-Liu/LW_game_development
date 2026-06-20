extends Node3D
class_name Room

var room_data: RoomData

func get_spawn_position(side: String):
	match side:
		"left":
			return $DoorLeft.global_position
		"right":
			return $DoorRight.global_position
		"up":
			return $DoorUp.global_position
		"down":
			return $DoorDown.global_position
	return global_position
