extends Control

# 节点绑定 
@onready var volume_slider = $VBoxContainer/MarginContainer/HBoxContainer/HSlider
@onready var volume_percent_label = $VBoxContainer/MarginContainer/HBoxContainer/Label2 # 原 "THIS IS A BUG" 节点
@onready var resolution_btn = $VBoxContainer/MarginContainer2/HBoxContainer/OptionButton
@onready var fullscreen_check = $VBoxContainer/MarginContainer3/HBoxContainer/CheckBox


# 简介：节点进入场景树时调用，负责读取配置、恢复 UI 初始状态并绑定所有交互信号。
func _ready() -> void:
	
	# --- 1. 初始化分辨率下拉菜单 ---
	# 清空默认选项
	resolution_btn.clear()
	# 获取支持的分辨率列表并逐一添加
	var res_keys = SettingsManager.RESOLUTIONS.keys()
	for key in res_keys:
		resolution_btn.add_item(key)
		
	# --- 2. 恢复全屏状态 ---
	# 从配置读取全屏参数并设置复选框状态
	fullscreen_check.button_pressed = SettingsManager.config.get_value("Graphics", "fullscreen", false)
	
	# --- 3. 恢复分辨率状态 ---
	# 读取当前分辨率配置，并在下拉菜单中自动匹配选中该项
	var current_res = SettingsManager.config.get_value("Graphics", "resolution", "1920 x 1080 (FHD)")
	var res_index = res_keys.find(current_res)
	if res_index != -1:
		resolution_btn.select(res_index)
		
	# --- 4. 恢复音量状态 ---
	# 读取当前系统音量，并同步给滑动条与文本标签
	var current_vol = SettingsManager.get_master_volume()
	volume_slider.value = current_vol
	_update_volume_label(current_vol)

	# --- 5. 绑定玩家交互信号 ---
	# 将 UI 控件的操作连接到对应的响应方法上
	volume_slider.value_changed.connect(_on_volume_changed)
	resolution_btn.item_selected.connect(_on_resolution_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

# 信号响应逻辑：将玩家操作下发给大管家

# 简介：处理音量滑动条变化事件，更新系统音量、刷新 UI 并播放测试反馈音。
func _on_volume_changed(value: float) -> void:
	# 更新全局音量设置
	SettingsManager.set_master_volume(value)
	# 刷新右侧百分比文本显示
	_update_volume_label(value)
	
	# 加入这一行：调用已有的音频系统播放 UI 测试音（需确保该路径下有声音文件）
	# 注意：如果之前没配 "ui_system" 的声音，可以在场景里临时建个 AudioStreamPlayer 节点来 play()
	BattleBus.play_sfx.emit("ui_system", "hover_sound", Vector3.ZERO)


# 简介：处理分辨率下拉框的选择事件，将选中的分辨率文本应用到系统设置。
func _on_resolution_selected(index: int) -> void:
	# 获取当前选中项对应的文本内容
	var selected_text = resolution_btn.get_item_text(index)
	# 传递给设置管理器应用修改
	SettingsManager.set_resolution(selected_text)


# 简介：处理全屏复选框的切换事件，更新系统的窗口显示模式。
func _on_fullscreen_toggled(toggled_on: bool) -> void:
	# 根据复选框状态开启或关闭全屏
	SettingsManager.set_fullscreen(toggled_on)


# ==========================================
# 辅助 UI 刷新
# ==========================================

# 简介：辅助方法，用于将 0.0~1.0 的浮点型音量值转换为易读的百分比字符串。
func _update_volume_label(val: float) -> void:
	# 把 0.0~1.0 的小数转换成 0~100 的整数百分比
	var percent = int(val * 100)
	# 拼接 % 符号并赋值给 UI 标签
	volume_percent_label.text = str(percent) + " %"
	
	
# ==========================================
# 输入与导航控制
# ==========================================

# 简介：监听未被其他控件消费的全局输入事件，用于捕获快捷键动作（如 ESC 返回）。
func _unhandled_input(event: InputEvent) -> void:
	# "ui_cancel" 是 Godot 默认的取消动作，通常绑定了 ESC 键
	if event.is_action_pressed("ui_cancel"):
		# 触发返回主菜单操作
		_return_to_main_menu()


# 简介：处理返回主菜单的完整逻辑，包含安全的场景树节点获取与动态转场加载。
func _return_to_main_menu() -> void:
	# 获取场景树根节点下的 MAIN 主节点
	var main_root = get_tree().root.get_node_or_null("MAIN")
	# 若主节点不存在，则直接中断执行防止报错
	if not main_root:
		return
		
	EventBus.load_scene.emit("main_menu")
