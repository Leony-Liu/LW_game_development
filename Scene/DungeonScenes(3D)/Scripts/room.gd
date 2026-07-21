extends Node3D
class_name Room

var room_data: RoomData

func get_spawn_position(side: String):
	match side:
		"left":
			return $Doors/DoorLeft.get_spawn_position()
		"right":
			return $Doors/DoorRight.get_spawn_position()
		"up":
			return $Doors/DoorUp.get_spawn_position()
		"down":
			return $Doors/DoorDown.get_spawn_position()
	return global_position


func get_player_spawn() -> Vector3:
	return $PlayerSpawn.global_position
