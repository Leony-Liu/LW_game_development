class_name BattleRoom
extends Node3D

## 房间数据变化时对外发送的信号
signal room_data_changed(updated_data: RoomData)

@export_group("挂载节点绑定")
@export var north_wall: Node3D
@export var east_wall: Node3D
@export var south_wall: Node3D
@export var west_wall: Node3D
@export var floor_root: Node3D
@export var ceiling_root: Node3D
@export var enemy_root: Node3D

@export_group("场景预制体")
## 实心墙体场景
@export var wall_scene: PackedScene
## 带门洞的墙体场景
@export var door_wall_scene: PackedScene
## 地面场景
@export var floor_scene: PackedScene
## 天花板场景
@export var ceiling_scene: PackedScene


# 本房间当前分配的敌人 ID (-1 表示无敌人)
var enemy_id: int = -1

# 纯代码变量（由 RoomSet 动态赋值，不暴露在检查器中）
var room_data: RoomData:
	set = set_room_data

func _ready() -> void:
	# 若 RoomSet 在 add_child 之前已赋值 room_data，进入节点树时立即构建
	if room_data:
		build_room()

## 接收 RoomSet 传递数据的入口
func set_room_data(new_data: RoomData) -> void:
	room_data = new_data
	# 若节点已进入场景树，赋值时立即触发重新构建
	if is_node_ready() and room_data:
		build_room()

## 根据 room_data 数据组装房间场景
func build_room() -> void:
	_setup_walls()
	_setup_floor_and_ceiling()
	_setup_enemies()

## 1. 组装四面墙体
func _setup_walls() -> void:
	var doors: Array[RoomData.Direction] = room_data.connected_doors
	
	_mount_scene(north_wall, door_wall_scene if RoomData.Direction.NORTH in doors else wall_scene)
	_mount_scene(east_wall,  door_wall_scene if RoomData.Direction.EAST in doors else wall_scene)
	_mount_scene(south_wall, door_wall_scene if RoomData.Direction.SOUTH in doors else wall_scene)
	_mount_scene(west_wall,  door_wall_scene if RoomData.Direction.WEST in doors else wall_scene)

## 2. 组装地面与天花板
func _setup_floor_and_ceiling() -> void:
	if floor_scene:
		_mount_scene(floor_root, floor_scene)
	if ceiling_scene:
		_mount_scene(ceiling_root, ceiling_scene)

## 3. 组装敌人（仅记录敌人 ID 并控制子节点显隐）
func _setup_enemies() -> void:
	if room_data and room_data.has_enemies:
		enemy_id = room_data.enemy_id
	else:
		enemy_id = -1

	if enemy_root:
		# 无敌人时隐藏根节点，有敌人时激活显示
		enemy_root.visible = (enemy_id != -1)
		
		# 预留透传：如果子节点挂载了脚本且包含 enemy_id 属性，直接向下同步
		for child in enemy_root.get_children():
			if "enemy_id" in child:
				child.enemy_id = enemy_id

## 挂载实例到指定父节点下
func _mount_scene(parent_node: Node3D, scene_to_instantiate: PackedScene) -> void:
	if not parent_node or not scene_to_instantiate:
		return
	_clear_children(parent_node)
	var instance = scene_to_instantiate.instantiate()
	parent_node.add_child(instance)

## 清理节点下原有子节点
func _clear_children(parent_node: Node3D) -> void:
	if not parent_node:
		return
	for child in parent_node.get_children():
		child.queue_free()

#region 状态更新与信号汇报

## 玩家进出房间状态同步
func set_player_inside(inside: bool) -> void:
	if not room_data or room_data.is_player_inside == inside:
		return
	room_data.is_player_inside = inside
	room_data_changed.emit(room_data)


## 玩家是否在附近状态同步
func set_player_nearby(nearby: bool) -> void:
	if not room_data or room_data.is_player_nearby == nearby:
		return
	room_data.is_player_nearby = nearby
	room_data_changed.emit(room_data)


## 房间敌人全部被消灭时调用
func clear_enemies() -> void:
	if not room_data or not room_data.has_enemies:
		return
	room_data.has_enemies = false
	room_data.enemy_id = -1
	enemy_id = -1
	
	if enemy_root:
		enemy_root.visible = false

	room_data_changed.emit(room_data)
#endregion
