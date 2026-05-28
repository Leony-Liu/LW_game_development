extends Control

# ==========================================
# 1. 节点精准绑定 (根据你的场景树路径)
# ==========================================
@onready var volume_slider = $VBoxContainer/MarginContainer/HBoxContainer/HSlider
@onready var volume_percent_label = $VBoxContainer/MarginContainer/HBoxContainer/Label2 # 原 "THIS IS A BUG" 节点
@onready var resolution_btn = $VBoxContainer/MarginContainer2/HBoxContainer/OptionButton
@onready var fullscreen_check = $VBoxContainer/MarginContainer3/HBoxContainer/CheckBox

func _ready() -> void:
	# ==========================================
	# 2. 初始化 UI 状态 (从 SettingsManager 读取数据)
	# ==========================================
	
	# 初始化分辨率下拉菜单
	resolution_btn.clear()
	var res_keys = SettingsManager.RESOLUTIONS.keys()
	for key in res_keys:
		resolution_btn.add_item(key)
		
	# 读取并设置当前全屏状态
	fullscreen_check.button_pressed = SettingsManager.config.get_value("Graphics", "fullscreen", false)
	
	# 读取并设置当前分辨率选择项
	var current_res = SettingsManager.config.get_value("Graphics", "resolution", "1920 x 1080 (FHD)")
	var res_index = res_keys.find(current_res)
	if res_index != -1:
		resolution_btn.select(res_index)
		
	# 读取并设置当前音量
	var current_vol = SettingsManager.get_master_volume()
	volume_slider.value = current_vol
	_update_volume_label(current_vol)

	# ==========================================
	# 3. 绑定玩家交互信号
	# ==========================================
	volume_slider.value_changed.connect(_on_volume_changed)
	resolution_btn.item_selected.connect(_on_resolution_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)


# ==========================================
# 4. 信号响应逻辑：将玩家操作发送给大管家
# ==========================================
func _on_volume_changed(value: float) -> void:
	SettingsManager.set_master_volume(value)
	_update_volume_label(value)
	
	# 加入这一行：调用你已有的音频系统播放 UI 测试音（请确保该路径下有声音文件）
	# 注意：如果你之前没配 "ui_system" 的声音，可以在场景里临时建个 AudioStreamPlayer 节点来 play()
	BattleBus.play_sfx.emit("ui_system", "hover_sound", Vector3.ZERO)

func _on_resolution_selected(index: int) -> void:
	var selected_text = resolution_btn.get_item_text(index)
	SettingsManager.set_resolution(selected_text)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	SettingsManager.set_fullscreen(toggled_on)


# ==========================================
# 5. 辅助 UI 刷新
# ==========================================
func _update_volume_label(val: float) -> void:
	# 把 0.0~1.0 的小数转换成 0~100 的整数百分比
	var percent = int(val * 100)
	volume_percent_label.text = str(percent) + " %"
