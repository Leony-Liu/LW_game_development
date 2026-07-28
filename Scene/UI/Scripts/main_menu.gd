extends Control

@onready var start_button: Button = %StartGame
@onready var file_button: Button = %FileList
@onready var options_button: Button = %Options
@onready var quit_button: Button = %QuitGame

@export_category("Navigation")
@export var battle_system_scene: PackedScene
@export var filelist_system_scene: PackedScene
@export var options_system_scene: PackedScene

@export_category("Transition")
@export_range(0.0, 2.0, 0.05) var transition_duration: float = 0.25


func _ready() -> void:
	start_button.pressed.connect(_on_start_game_pressed)
	file_button.pressed.connect(_on_filelist_open_pressed)
	options_button.pressed.connect(_on_options_open_pressed)
	quit_button.pressed.connect(_on_quit_game_pressed)

# ==========================================
# 点击按钮后触发
# ==========================================
# 开始游戏按钮
func _on_start_game_pressed() -> void:
	_open_system(
		battle_system_scene,
		"battle_system_scene",
		{
			"entry_source": "main_menu",
			"mode": "battle_test",
			"debug_mode": true,
		}
	)

# 存档列表按钮
func _on_filelist_open_pressed() -> void:
	_open_system(
		filelist_system_scene,
		"filelist_system_scene",
		{"entry_source": "main_menu"}
	)

# 设置按钮
func _on_options_open_pressed() -> void:
	_open_system(
		options_system_scene,
		"options_system_scene",
		{"entry_source": "main_menu"}
	)

# 退出游戏按钮
func _on_quit_game_pressed() -> void:
	get_tree().quit()


# ==========================================
# 外部暴露方法
# ==========================================
func _open_system(
	target_scene: PackedScene,
	export_name: String,
	context: Dictionary = {}
) -> void:
	# 防呆检查
	if target_scene == null:
		push_error("主菜单错误：未配置 %s。" % export_name)
		return

	var main_root := _get_main_root()
	if main_root == null:
		push_error("主菜单错误：找不到 MAIN 根节点。请确认项目从 MAIN.tscn 启动。")
		return

	if not main_root.has_method("load_system_scene"):
		push_error("主菜单错误：MAIN 没有 load_system_scene() 方法。")
		return

	# Callable 持有的是 MAIN，而不是当前菜单节点。
	# 菜单在回调中被移除后，调用仍然有效。
	var load_callback := Callable(
		main_root,
		"load_system_scene"
	).bind(
		target_scene,
		context
	)

	SceneManager.transition_to(load_callback, transition_duration)


func _get_main_root() -> Node:
	# 在当前架构中 current_scene 应当始终是 MAIN。
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("load_system_scene"):
		return current_scene

	# 兼容节点名称固定为 MAIN 的情况。
	return get_tree().root.get_node_or_null("MAIN")
