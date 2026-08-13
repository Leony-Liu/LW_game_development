extends Control


@onready var start_button: Button = %StartGame
@onready var file_button: Button = %FileList
@onready var options_button: Button = %Options
@onready var quit_button: Button = %QuitGame


@export_category("Navigation")

@export var shelter_scene: PackedScene

@export var filelist_system_scene: PackedScene

@export var options_system_scene: PackedScene


@export_category("Transition")

@export_range(0.0, 2.0, 0.05)
var transition_duration: float = 0.25


func _ready() -> void:
	start_button.pressed.connect(
		_on_start_game_pressed
	)

	file_button.pressed.connect(
		_on_filelist_open_pressed
	)

	options_button.pressed.connect(
		_on_options_open_pressed
	)

	quit_button.pressed.connect(
		_on_quit_game_pressed
	)


# ============================================================
# Start
# ============================================================


func _on_start_game_pressed() -> void:
	var last_save_id: String = (
		SaveManager.get_last_save_id()
	)

	# --------------------------------------------------------
	# 没有任何存档
	# --------------------------------------------------------

	if last_save_id.is_empty():
		_open_system(
			filelist_system_scene,
			"filelist_system_scene",
			{
				"entry_source": "main_menu",
				"reason": "no_save"
			}
		)

		return

	# --------------------------------------------------------
	# 有最近使用存档
	# --------------------------------------------------------

	if not SaveManager.load_save(
		last_save_id
	):
		# 文件异常时退回存档列表，
		# 不让开始游戏按钮直接失效。
		_open_system(
			filelist_system_scene,
			"filelist_system_scene",
			{
				"entry_source": "main_menu",
				"reason": "load_failed"
			}
		)

		return

	_open_system(
		shelter_scene,
		"shelter_scene",
		{
			"entry_source": "continue",
			"save_id": last_save_id
		}
	)


# ============================================================
# File List
# ============================================================


func _on_filelist_open_pressed() -> void:
	_open_system(
		filelist_system_scene,
		"filelist_system_scene",
		{
			"entry_source": "main_menu"
		}
	)


# ============================================================
# Options
# ============================================================


func _on_options_open_pressed() -> void:
	_open_system(
		options_system_scene,
		"options_system_scene",
		{
			"entry_source": "main_menu"
		}
	)


# ============================================================
# Quit
# ============================================================


func _on_quit_game_pressed() -> void:
	get_tree().quit()


# ============================================================
# Navigation
# ============================================================


func _open_system(
	target_scene: PackedScene,
	export_name: String,
	context: Dictionary = {}
) -> void:
	if target_scene == null:
		push_error(
			"MainMenu: 未配置 %s。"
			% export_name
		)
		return

	var main_root: Node = _get_main_root()

	if main_root == null:
		push_error(
			"MainMenu: 找不到 MAIN。"
		)
		return

	if not main_root.has_method(
		"load_system_scene"
	):
		push_error(
			"MainMenu: MAIN 不支持 load_system_scene()。"
		)
		return

	var callback: Callable = Callable(
		main_root,
		"load_system_scene"
	).bind(
		target_scene,
		context
	)

	SceneManager.transition_to(
		callback,
		transition_duration
	)


func _get_main_root() -> Node:
	var current_scene: Node = (
		get_tree().current_scene
	)

	if (
		current_scene != null
		and current_scene.has_method(
			"load_system_scene"
		)
	):
		return current_scene

	return get_tree().root.get_node_or_null(
		"MAIN"
	)
