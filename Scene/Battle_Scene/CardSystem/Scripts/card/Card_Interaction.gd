extends Node

# 左键点击时发送交互请求。
signal left_clicked

# 右键点击时发送交互请求。
signal right_clicked

# 鼠标进入卡牌时发送悬浮信号。
signal hover_started

# 鼠标离开卡牌时发送悬浮结束信号。
signal hover_ended

# 保存负责接收输入的 Card 根节点。
var parent_control: Control

# 控制当前是否允许发送交互信号。
var is_enabled: bool = false


# 绑定 Card 根节点并连接鼠标信号。
func setup(control: Control) -> void:
	parent_control = control
	
	parent_control.mouse_entered.connect(_on_mouse_entered)
	parent_control.mouse_exited.connect(_on_mouse_exited)
	parent_control.gui_input.connect(_on_gui_input)


# 开启或关闭玩家对这张卡牌的操作。
func set_enabled(value: bool) -> void:
	is_enabled = value


# 鼠标进入时只在允许交互的状态下发送信号。
func _on_mouse_entered() -> void:
	if not is_enabled:
		return
	
	hover_started.emit()


# 鼠标离开时只在允许交互的状态下发送信号。
func _on_mouse_exited() -> void:
	if not is_enabled:
		return
	
	hover_ended.emit()


# 接收鼠标按钮输入并区分左右键。
func _on_gui_input(event: InputEvent) -> void:
	if not is_enabled:
		return
	
	var mouse_event := event as InputEventMouseButton
	
	if not mouse_event or not mouse_event.pressed:
		return
	
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		left_clicked.emit()
		parent_control.accept_event()
	
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit()
		parent_control.accept_event()
