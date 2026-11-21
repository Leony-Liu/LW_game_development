class_name DoorSet
extends Node3D

signal door_opened_relay(door: Node3D)

@export_group("场景预制体")
@export var door_scene: PackedScene
var _interaction_player_ref: WeakRef

# 由 World 注入真实玩家，新建门只使用共享派发入口。
func configure_interaction_player(player: CharacterBody3D) -> bool:
	if not is_instance_valid(player):
		push_error("[DoorSet] 交互配置失败：缺少真实玩家。")
		return false
	_interaction_player_ref = weakref(player)
	return true

# 查询现有门节点，不维护第二份交互注册表。
func get_interaction_candidates(player: CharacterBody3D) -> Array[Door]:
	var candidates: Array[Door] = []
	for child in get_children():
		if child is Door and child.can_interact(player):
			candidates.append(child)
	return candidates


## 接收地图数据；任一必需门失败时清除本批实例并返回失败。
func build_doors(blueprint: Dictionary) -> bool:
	clear_doors()
	var doors_value: Variant = blueprint.get("doors")
	if not doors_value is Dictionary:
		push_error("DoorSet ： 门组装失败：地图缺少有效门数据。")
		return false
	var doors: Dictionary = doors_value
	if not doors.is_empty() and door_scene == null:
		push_error("DoorSet ： 门组装失败：缺少 door_scene。")
		return false
	print("DoorSet ： 开始组装门，数量：%d。" % doors.size())
	for door_pos in doors.keys():
		if not door_pos is Vector2 or doors[door_pos] not in ["horizontal", "vertical"]:
			return _fail_build("门坐标或朝向无效。")
		var candidate := door_scene.instantiate()
		var door_instance: Door = candidate as Door
		if door_instance == null:
			if candidate != null:
				candidate.free()
			return _fail_build("door_scene 根节点不是 Door。")
		if not is_instance_valid(door_instance.door_body) or not is_instance_valid(door_instance.interaction_area):
			door_instance.free()
			return _fail_build("Door 缺少门体或交互区域引用。")
		add_child(door_instance)
		if _interaction_player_ref != null:
			door_instance.configure_interaction_dispatch(_interaction_player_ref.get_ref())
		door_instance.position = Vector3(door_pos.x, 0.0, door_pos.y)
		var is_horizontal: bool = (doors[door_pos] == "horizontal")
		door_instance.rotation.y = deg_to_rad(90.0) if is_horizontal else 0.0
		# Door 类型保证门事件存在，中继给 WorldManager。
		door_instance.door_opened.connect(func(d): door_opened_relay.emit(d))
	print("DoorSet ： 门组装完成，数量：%d。" % get_child_count())
	return true


# 报告失败并撤下本批全部门。
func _fail_build(reason: String) -> bool:
	push_error("DoorSet ： 门组装失败：%s" % reason)
	clear_doors()
	return false

func clear_doors() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
