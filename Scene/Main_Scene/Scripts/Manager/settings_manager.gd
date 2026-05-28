extends Node

const SETTINGS_FILE = "user://settings.cfg"
var config = ConfigFile.new()

# 预设的常用 16:9 分辨率字典
const RESOLUTIONS = {
	"1280 x 720 (HD)": Vector2i(1280, 720),
	"1600 x 900 (HD+)": Vector2i(1600, 900),
	"1920 x 1080 (FHD)": Vector2i(1920, 1080),
	"2560 x 1440 (2K)": Vector2i(2560, 1440)
}

func _ready() -> void:
	# 游戏启动时，自动读取本地设置并应用
	load_settings()

# ==========================================
# 声音设置 (Audio)
# ==========================================
func set_master_volume(linear_volume: float) -> void:
	# linear_volume 是 UI 滑块传来的 0.0 到 1.0 的值
	# Godot 底层用的是分贝(dB)，必须用 linear_to_db 转换，否则听感会很奇怪
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_volume))
	
	# 存入配置表
	config.set_value("Audio", "master_volume", linear_volume)
	save_settings()

func get_master_volume() -> float:
	return config.get_value("Audio", "master_volume", 1.0) # 默认 1.0 (最大声)

# ==========================================
# 画面设置 (Graphics)
# ==========================================
func set_resolution(res_key: String) -> void:
	if RESOLUTIONS.has(res_key):
		var target_size = RESOLUTIONS[res_key]
		DisplayServer.window_set_size(target_size)
		
		# 将窗口居中 (非全屏时体验更好)
		var screen_center = DisplayServer.screen_get_position() + DisplayServer.screen_get_size() / 2
		DisplayServer.window_set_position(screen_center - target_size / 2)
		
		config.set_value("Graphics", "resolution", res_key)
		save_settings()
		
		print("⚙️ 系统真实分辨率已修改为: ", DisplayServer.window_get_size())

func set_fullscreen(is_full: bool) -> void:
	if is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	config.set_value("Graphics", "fullscreen", is_full)
	save_settings()

# ==========================================
# 本地存取逻辑
# ==========================================
func save_settings() -> void:
	config.save(SETTINGS_FILE)

func load_settings() -> void:
	var err = config.load(SETTINGS_FILE)
	if err != OK:
		print("未找到本地设置，使用默认配置。")
		return
	
	# 读取并应用声音
	set_master_volume(get_master_volume())
	
	# 读取并应用画面
	var saved_res = config.get_value("Graphics", "resolution", "1920 x 1080 (FHD)")
	set_resolution(saved_res)
	
	var is_full = config.get_value("Graphics", "fullscreen", false)
	set_fullscreen(is_full)
