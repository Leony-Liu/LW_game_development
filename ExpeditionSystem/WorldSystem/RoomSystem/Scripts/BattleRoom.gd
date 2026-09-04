class_name BattleRoom
extends Node3D

# 在检查器中将 Prefab 文件夹下的 Wall.tscn 和 Door.tscn 拖入这两个槽位
@export var wall_prefab: PackedScene
@export var door_prefab: PackedScene

# 缓存四个方向的挂载点节点，与 RoomData 里的 "N", "E", "S", "W" 对应
@onready var wall_anchors = {
	"N": $Field/NorthWall,
	"E": $Field/EastWall,
	"S": $Field/SouthWall,
	"W": $Field/WestWall
}

@onready var enemy_visual_root = $EnemyVisualRoot

var room_data: RoomData

# 由 RoomSet 在实例化本房间时主动调用
func initialize_room(data: RoomData) -> void:
	room_data = data
	
	_setup_walls_and_doors()
	_setup_enemy()

func _setup_walls_and_doors() -> void:
	if not wall_prefab or not door_prefab:
		push_error("[BattleRoom] 未在检查器中配置 Wall 或 Door 的 Prefab！")
		return

	for dir in wall_anchors.keys():
		var anchor = wall_anchors[dir]
		
		# 1. 清理你在编辑器里为了预览而手动摆放的占位节点（如 Wall2, Door 等）
		for child in anchor.get_children():
			child.queue_free()
			
		# 2. 根据数据查验该方向是否应该有门
		var has_door = room_data.doors.has(dir)
		var prefab_to_spawn = door_prefab if has_door else wall_prefab
		
		# 3. 实例化并添加为子节点（它会自动继承你预设好的东西南北旋转角度）
		var instance = prefab_to_spawn.instantiate()
		anchor.add_child(instance)

func _setup_enemy() -> void:
	# 初始阶段，先把编辑器里的占位怪物隐藏
	enemy_visual_root.visible = false
	
	if room_data.has_enemy and not room_data.is_cleared:
		# 如果房间有怪且没被杀，显示怪物节点
		enemy_visual_root.visible = true
		
		# TODO: 如果未来有多种怪物，可以在这里根据 room_data.enemy_id 
		# 动态加载对应的 3D 怪物模型并 add_child 到 enemy_visual_root 下

# 供外部（如 WorldManager 结算战斗胜利后）调用，抹除怪物
func clear_enemy_visual() -> void:
	# 播放一个简单的消失特效（或者直接隐藏/删除）
	enemy_visual_root.visible = false
	
	# 如果是动态实例化的模型，这里应该使用：
	# for child in enemy_visual_root.get_children():
	#     child.queue_free()
