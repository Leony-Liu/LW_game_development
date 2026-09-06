class_name DoorSet
extends Node3D

signal door_opened_relay(door: Node3D)

@export_group("场景预制体")
@export var door_scene: PackedScene


## 接收地图蓝图构建所有门实体
func build_doors(blueprint: Dictionary) -> void:
	clear_doors()
	var doors: Dictionary = blueprint.get("doors", {})

	for door_pos: Vector2 in doors.keys():
		var door_instance = door_scene.instantiate() as Node3D
		add_child(door_instance)
		
		door_instance.position = Vector3(door_pos.x, 0.0, door_pos.y)
		var is_horizontal: bool = (doors[door_pos] == "horizontal")
		door_instance.rotation.y = deg_to_rad(90.0) if is_horizontal else 0.0

		# 连接每扇门的开门信号
		if door_instance.has_signal("door_opened"):
			door_instance.door_opened.connect(func(d): door_opened_relay.emit(d))

func clear_doors() -> void:
	for child in get_children():
		child.queue_free()
