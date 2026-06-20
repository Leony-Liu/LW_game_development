extends Node3D
class_name Room

var room_data: RoomData

func get_spawn_position(side: String):
	 match side:
		"left":
			return $SpawnLeft.global_position
		"right":
			return $SpawnRight.global_position
		"up":
			return $SpawnUp.global_position
		"down":
			return $SpawnDown.global_position
	return global_position
