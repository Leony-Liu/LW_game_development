#地图中的门
#作用：1、用于在地图中实例化场景的门；2、储存需要跳转过去从场景的路径
extends Node3D
class_name Door

@export var prompt_text: String = "OPEN THE DOOR [E]"#UI文字
var is_player_in_range: bool = false#玩家是否进入

@export_group("门在房间场景中的设置")
@export var door_id: int = 0#门的ID
@export var direction: String#门的朝向：上下左右
var target_room_id: int = -1
var enter_side: String

func get_spawn_position():
	return $SpawnPoint.global_position

func _ready() -> void:
	pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		is_player_in_range = true
		# 通知 UI 层显示提示
		EventBus.interaction_prompt_requested.emit(true, prompt_text, self)
		#print("UI信号已发出")
	pass


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		is_player_in_range = false
		# 通知 UI 层隐藏提示
		EventBus.interaction_prompt_requested.emit(false, "", self)
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if is_player_in_range and event.is_action_pressed("interact"): # 需要在输入映射定义 interact (如 E 键)
		open_chest()

func open_chest():
	print("已开启房间门")
	# 逻辑：播放动画、掉落物品、自毁或改变状态
	var dungeon = get_tree().get_first_node_in_group("dungeon_manager")
	dungeon.enter_door(self)
	# queue_free() 或播放打开动画
	pass
