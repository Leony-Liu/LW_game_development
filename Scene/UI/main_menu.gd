extends Control

@onready var start_button = $MarginContainer/VBoxContainer/startgame

# 【专业做法】：暴露出目标关卡的挂载点
@export_category("Navigation")
@export var target_world_scene: PackedScene

func _ready() -> void:
	start_button.pressed.connect(_on_start_game_pressed)

func _on_start_game_pressed() -> void:
	if not target_world_scene:
		push_error("主菜单错误：未配置 START GAME 的目标场景！")
		return
		
	var main_root = get_tree().root.get_node_or_null("MAIN")
	if not main_root:
		push_error("找不到 MAIN 根节点，请确保游戏从 MAIN.tscn 启动")
		return
	
	var load_base_logic = func():
		# 直接传递资源对象，而不是字符串
		main_root.load_world_scene(target_world_scene) 
		
	SceneManager.transition_to(load_base_logic, 0.5)
