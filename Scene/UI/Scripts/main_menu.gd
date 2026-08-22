extends Control

# 连接场景内节点
@onready var start_button: Button = %StartGame
@onready var file_button: Button = %FileList
@onready var options_button: Button = %Options
@onready var quit_button: Button = %QuitGame

# 连接按钮所触发的对应方法
func _ready() -> void:
	start_button.pressed.connect(_on_start_game_pressed)
	file_button.pressed.connect(_on_filelist_open_pressed)
	options_button.pressed.connect(_on_options_open_pressed)
	quit_button.pressed.connect(_on_quit_game_pressed)

# 点“开始游戏”时，看看有没有最新存档，有就接着玩，没有或者读档失败就跳去存档列表
func _on_start_game_pressed() -> void:
	# 获取最近存档
	var last_save_id: String = SaveManager.get_last_save_id()
	
	# 没有任何存档
	if last_save_id.is_empty():
		EventBus.load_scene.emit("filelist")
		return

	# 有最近使用存档
	if not SaveManager.load_save(last_save_id):
		EventBus.load_scene.emit("filelist")
		return

	EventBus.load_scene.emit("shelter")

# 点存档按钮时，直接打开存档列表界面。
func _on_filelist_open_pressed() -> void:
	EventBus.load_scene.emit("filelist")

# 点设置按钮时，直接打开设置界面。
func _on_options_open_pressed() -> void:
	EventBus.load_scene.emit("options")

# 点退出按钮时，直接关掉整个游戏进程。
func _on_quit_game_pressed() -> void:
	get_tree().quit()
