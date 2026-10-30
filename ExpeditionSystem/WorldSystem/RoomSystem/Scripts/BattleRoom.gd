## 按 RoomData 组装单个房间的结构与敌人表现。
## 上报真实玩家入室，并提供当前敌人的场景接近锚点。
class_name BattleRoom
extends Node3D

signal extraction_requested(room: RoomData, facility: Node3D)
signal player_entered(room: RoomData)

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
@export var encounter_approach_anchor: Node3D
@export var room_entry_area: Area3D
@export var room_entry_shape: CollisionShape3D

@export_group("场景预制体")
## 实心墙体场景
@export var wall_scene: PackedScene
## 带门洞的墙体场景
@export var door_wall_scene: PackedScene
## 地面场景
@export var floor_scene: PackedScene
## 天花板场景
@export var ceiling_scene: PackedScene

@export_group("初始房设施")
@export var extraction_facility_mount: Node3D
@export var extraction_facility_scene: PackedScene

var _extraction_facility: Node3D
var _entry_player: CharacterBody3D
var _player_inside_entry := false


# 本房间当前分配的敌人 ID (-1 表示无敌人)
var enemy_id: int = -1
var is_assembled: bool = false

# 纯代码变量（由 RoomSet 动态赋值，不暴露在检查器中）
var room_data: RoomData:
	set = set_room_data

func _ready() -> void:
	set_physics_process(false)
	if is_instance_valid(room_entry_area):
		room_entry_area.body_entered.connect(_on_entry_body_entered)
		room_entry_area.body_exited.connect(_on_entry_body_exited)
	# 若 RoomSet 在 add_child 之前已赋值 room_data，进入节点树时立即构建
	if room_data:
		build_room()

# 接收拥有者绑定的唯一玩家物理体，不通过名字或任意 CharacterBody 判定。
func configure_entry_player(player_body: CharacterBody3D) -> void:
	_entry_player = player_body
	_player_inside_entry = false
	set_physics_process(false)

# 面积重叠后仍检查玩家原点，避免胶囊边缘提前揭示邻室。
func is_player_inside_entry() -> bool:
	if not is_assembled or not is_instance_valid(_entry_player) or not room_entry_area.overlaps_body(_entry_player):
		return false
	var local_player := room_entry_shape.to_local(_entry_player.global_position)
	var half_size: Vector3 = (room_entry_shape.shape as BoxShape3D).size * 0.5
	return absf(local_player.x) < half_size.x and absf(local_player.z) < half_size.z

# 供首次物理同步后补查，已在室内时不重复通知。
func refresh_player_room_occupancy() -> void:
	if not is_assembled or not is_instance_valid(_entry_player):
		return
	set_physics_process(room_entry_area.overlaps_body(_entry_player))
	var inside := is_player_inside_entry()
	if inside and not _player_inside_entry:
		_player_inside_entry = true
		player_entered.emit(room_data)
	else:
		_player_inside_entry = inside

# 只在玩家与触发器重叠期间跟踪是否真正跨过房间内侧边界。
func _physics_process(_delta: float) -> void:
	refresh_player_room_occupancy()

# 其他物理体不会启动检测或产生探索记录。
func _on_entry_body_entered(body: Node3D) -> void:
	if body == _entry_player:
		refresh_player_room_occupancy()

# 离开后允许下次真实重入再次通知当前位置。
func _on_entry_body_exited(body: Node3D) -> void:
	if body == _entry_player:
		_player_inside_entry = false
		set_physics_process(false)

## 接收 RoomSet 传递数据的入口
func set_room_data(new_data: RoomData) -> void:
	room_data = new_data
	# 若节点已进入场景树，赋值时立即触发重新构建
	if is_node_ready() and room_data:
		build_room()


# 验证本房间实际需要的结构和敌人接近节点。
func _validate_assembly() -> bool:
	if room_data == null:
		push_error("BattleRoom ： 房间组装失败：缺少 RoomData。")
		return false
	if not is_instance_valid(room_entry_area) or not is_instance_valid(room_entry_shape) or not room_entry_shape.shape is BoxShape3D:
		push_error("[BattleRoom] 房间组装失败：缺少有效的入室检测区域或 BoxShape3D。")
		return false
	if not is_instance_valid(north_wall) or not is_instance_valid(east_wall) or not is_instance_valid(south_wall) or not is_instance_valid(west_wall):
		push_error("BattleRoom ： 房间组装失败：缺少墙体挂载节点。")
		return false
	if not is_instance_valid(floor_root) or not is_instance_valid(ceiling_root) or floor_scene == null or ceiling_scene == null:
		push_error("BattleRoom ： 房间组装失败：缺少必需的地板或天花板节点/场景。")
		return false
	for direction in [RoomData.Direction.NORTH, RoomData.Direction.EAST, RoomData.Direction.SOUTH, RoomData.Direction.WEST]:
		if direction in room_data.connected_doors and door_wall_scene == null:
			push_error("BattleRoom ： 房间组装失败：门洞墙体场景缺失。")
			return false
		if direction not in room_data.connected_doors and wall_scene == null:
			push_error("BattleRoom ： 房间组装失败：实心墙体场景缺失。")
			return false
	return true


## 根据 room_data 数据组装房间场景，并保存可供 RoomSet 检查的结果。
func build_room() -> bool:
	is_assembled = false
	_player_inside_entry = false
	if not _validate_assembly():
		_clear_partial_assembly()
		return false
	if not _setup_walls() or not _setup_floor_and_ceiling():
		_clear_partial_assembly()
		return false
	_setup_enemies()
	if not _setup_extraction_facility():
		_clear_partial_assembly()
		return false
	is_assembled = true
	return true


# 每次重建先撤下旧设施，只按权威 INITIAL 标记创建一次。
func _setup_extraction_facility() -> bool:
	_clear_extraction_facility()
	if room_data.room_type != RoomData.RoomType.INITIAL:
		return true
	if not is_instance_valid(extraction_facility_mount) or extraction_facility_scene == null:
		push_error("[BattleRoom] 初始房组装失败：缺少撤离设施挂载点或场景。")
		return false
	var candidate := extraction_facility_scene.instantiate()
	if not candidate is Node3D or candidate.get_script() != preload("res://ExpeditionSystem/WorldSystem/RoomSystem/Scripts/ExtractionFacility.gd") or not candidate.validate_configuration():
		if candidate != null:
			candidate.free()
		push_error("[BattleRoom] 初始房组装失败：撤离设施场景或交互配置无效。")
		return false
	_extraction_facility = candidate
	extraction_facility_mount.add_child(candidate)
	candidate.interaction_requested.connect(_on_extraction_requested.bind(candidate))
	return true


# 本房间只上报属于自己当前实例的设施意图。
func _on_extraction_requested(facility: Node3D) -> void:
	if is_instance_valid(facility) and get_extraction_facility() == facility:
		extraction_requested.emit(room_data, facility)


# 按本房间的类型和装配结果查询设施，不从坐标推断初始房。
func get_extraction_facility() -> Node3D:
	if not is_assembled or room_data == null or room_data.room_type != RoomData.RoomType.INITIAL:
		return null
	return _extraction_facility if is_instance_valid(_extraction_facility) else null


# 撤下时立即断开旧实例，延迟释放不留下可交互副本。
func _clear_extraction_facility() -> void:
	if is_instance_valid(_extraction_facility):
		_extraction_facility.get_parent().remove_child(_extraction_facility)
		_extraction_facility.queue_free()
	_extraction_facility = null

## 1. 组装四面墙体
func _setup_walls() -> bool:
	var doors: Array[RoomData.Direction] = room_data.connected_doors
	return (
		_mount_scene(north_wall, door_wall_scene if RoomData.Direction.NORTH in doors else wall_scene, "北墙")
		and _mount_scene(east_wall, door_wall_scene if RoomData.Direction.EAST in doors else wall_scene, "东墙")
		and _mount_scene(south_wall, door_wall_scene if RoomData.Direction.SOUTH in doors else wall_scene, "南墙")
		and _mount_scene(west_wall, door_wall_scene if RoomData.Direction.WEST in doors else wall_scene, "西墙")
	)

## 2. 组装地面与天花板
func _setup_floor_and_ceiling() -> bool:
	return _mount_scene(floor_root, floor_scene, "地板") and _mount_scene(ceiling_root, ceiling_scene, "天花板")

## 3. 组装敌人（仅记录敌人 ID 并控制子节点显隐）
func _setup_enemies() -> void:
	if room_data and room_data.has_enemies:
		enemy_id = room_data.enemy_id
	else:
		enemy_id = -1

	if enemy_root:
		# 无敌人时隐藏根节点，有敌人时激活显示
		enemy_root.visible = room_data.has_enemies and AllEnemyData.get_all_enemy_data().has(enemy_id)
		
		# 预留透传：如果子节点挂载了脚本且包含 enemy_id 属性，直接向下同步
		for child in enemy_root.get_children():
			if "enemy_id" in child:
				child.enemy_id = enemy_id

## 挂载实例到指定父节点下
func _mount_scene(parent_node: Node3D, scene_to_instantiate: PackedScene, component_name: String) -> bool:
	if not is_instance_valid(parent_node) or scene_to_instantiate == null:
		push_error("BattleRoom ： %s组装失败：必需节点或场景缺失。" % component_name)
		return false
	var instance := scene_to_instantiate.instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.free()
		push_error("BattleRoom ： %s组装失败：场景根节点不是 Node3D。" % component_name)
		return false
	_clear_children(parent_node)
	parent_node.add_child(instance)
	return true


# 装配中途失败时移除已挂载的结构，不保留半成品。
func _clear_partial_assembly() -> void:
	set_physics_process(false)
	_player_inside_entry = false
	_clear_extraction_facility()
	for mount in [north_wall, east_wall, south_wall, west_wall, floor_root, ceiling_root]:
		if is_instance_valid(mount):
			_clear_children(mount)
	enemy_id = -1
	if is_instance_valid(enemy_root):
		enemy_root.visible = false

## 清理节点下原有子节点
func _clear_children(parent_node: Node3D) -> void:
	if not is_instance_valid(parent_node):
		return
	for child in parent_node.get_children():
		parent_node.remove_child(child)
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
		# 保留接近锚点，移除本场战斗的敌人表现实例。
		for child in enemy_root.get_children():
			if child != encounter_approach_anchor:
				child.queue_free()

	room_data_changed.emit(room_data)


# 返回本房间当前敌人的场景配置观察锚点。
func get_encounter_approach_target() -> Node3D:
	if room_data == null or not room_data.has_enemies:
		return null
	if enemy_id < 0 or enemy_id != room_data.enemy_id:
		return null
	if not is_instance_valid(enemy_root) or not enemy_root.visible:
		return null
	if not is_instance_valid(encounter_approach_anchor):
		return null
	if not encounter_approach_anchor.is_inside_tree():
		return null
	return encounter_approach_anchor


# 仅返回本房间当前敌人的可选表现节点，不暴露敌人定位根节点。
func get_enemy_visual() -> EnemyVisual:
	if enemy_id < 0 or not is_instance_valid(enemy_root) or not enemy_root.visible:
		return null
	return enemy_root.get_node_or_null("EnemyVisual") as EnemyVisual
#endregion
