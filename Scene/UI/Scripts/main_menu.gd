extends Control

@onready var start_button = %StartGame
@onready var file_button = %FileList
@onready var options_button = %Options
@onready var quit_button = %QuitGame


@export_category("Navigation")
@export var battle_world_scene: PackedScene
@export var battle_ui_scene: PackedScene
@export var filelist_scene: PackedScene
@export var options_scene: PackedScene


func _ready() -> void:
	start_button.pressed.connect(_on_start_game_pressed)
	file_button.pressed.connect(_filelist_open_pressed)
	options_button.pressed.connect(_options_open_pressed)
	quit_button.pressed.connect(_on_quit_game_pressed)
	

# ==========================================
# 开始游戏按钮回调逻辑 (继续上次游戏)
# ==========================================

func _on_start_game_pressed() -> void:
	if battle_world_scene == null:
		push_error("主菜单错误：未配置 battle_world_scene。")
		return

	if battle_ui_scene == null:
		push_error("主菜单错误：未配置 battle_ui_scene。")
		return

	# 因为你始终没有真正切换主场景，所以 current_scene 就是 MAIN。
	var main_root := get_tree().current_scene

	if main_root == null:
		push_error("主菜单错误：无法取得当前 MAIN 场景。")
		return

	if not main_root.has_method("load_combat_scene"):
		push_error("主菜单错误：当前主场景没有 load_combat_scene() 方法。")
		return

	# 把 MAIN 的方法及参数封装成 Callable。
	# 这样回调不依赖 main_menu 自身，菜单被清除后也没有引用问题。
	var load_battle_callback := Callable(
		main_root,
		"load_combat_scene"
	).bind(
		battle_world_scene,
		battle_ui_scene
	)

	SceneManager.transition_to(load_battle_callback, 0.5)

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

		main_root.load_ui_scene(filelist_scene) 
		
	# 4. 调用全局转场管理器，0.5秒黑屏过渡
	SceneManager.transition_to(load_filelist_logic, 0.1)

func _options_open_pressed() -> void:
	if not options_scene:
		push_error("主菜单错误：未配置 Options (设置) 的目标场景！")
		return
		
	var main_root = get_tree().root.get_node_or_null("MAIN")
	if not main_root:
		push_error("找不到 MAIN 根节点，请确保游戏从 MAIN.tscn 启动")
		return
	
	var load_options_logic = func():
		# 设置界面同样是 UI，调用 load_ui_scene
		main_root.load_ui_scene(options_scene) 
		
	SceneManager.transition_to(load_options_logic, 0.1)


# ==========================================
# 退出游戏回调逻辑
# ==========================================
func _on_quit_game_pressed() -> void:
	# 干净利落地关闭整个游戏程序，退回桌面
	get_tree().quit()
