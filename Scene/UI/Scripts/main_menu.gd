extends Control

@onready var start_button = $MarginContainer/VBoxContainer/startgame
@onready var file_button = $MarginContainer/VBoxContainer/filelist

# 【专业做法】：暴露出目标关卡的挂载点
@export_category("Navigation")
@export var startgame_scene: PackedScene
@export var filelist_scene: PackedScene

func _ready() -> void:
	start_button.pressed.connect(_on_start_game_pressed)
	file_button.pressed.connect(_filelist_open_pressed)

# ==========================================
# 开始游戏按钮回调逻辑
# ==========================================
func _on_start_game_pressed() -> void:
	if not startgame_scene:
		push_error("主菜单错误：未配置 START GAME 的目标场景！")
		return
		
	var main_root = get_tree().root.get_node_or_null("MAIN")
	if not main_root:
		push_error("找不到 MAIN 根节点，请确保游戏从 MAIN.tscn 启动")
		return
	
	var load_base_logic = func():
		# 直接传递资源对象，而不是字符串
		main_root.load_world_scene(startgame_scene) 
		
	SceneManager.transition_to(load_base_logic, 0.5)

# ==========================================
# 存档列表按钮回调逻辑
# ==========================================
func _filelist_open_pressed() -> void:
	# 1. 安全校验：检查是否在右侧检查器挂载了场景
	if not filelist_scene:
		push_error("主菜单错误：未配置 File List (存档列表) 的目标场景！")
		return
		
	# 2. 获取 MAIN 根节点
	var main_root = get_tree().root.get_node_or_null("MAIN")
	if not main_root:
		push_error("找不到 MAIN 根节点，请确保游戏从 MAIN.tscn 启动")
		return
	
	# 3. 定义跳转逻辑 (闭包)
	var load_filelist_logic = func():
		# 【关键区别】：因为存档列表是 UI，所以这里调用 load_ui_scene
		main_root.load_ui_scene(filelist_scene) 
		
	# 4. 调用全局转场管理器，0.5秒黑屏过渡
	SceneManager.transition_to(load_filelist_logic, 0.1)
