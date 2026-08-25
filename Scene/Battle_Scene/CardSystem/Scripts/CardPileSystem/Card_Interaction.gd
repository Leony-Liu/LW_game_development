extends Node

# 左键点击
signal left_clicked
# 右键点击
signal right_clicked

signal hover_started
signal hover_ended


var parent_control: Control

func setup(control: Control) -> void:
	parent_control = control
	parent_control.mouse_entered.connect(_on_mouse_entered)
	parent_control.mouse_exited.connect(_on_mouse_exited)
	parent_control.gui_input.connect(_on_gui_input)

func _on_mouse_entered() -> void:
	hover_started.emit()

func _on_mouse_exited() -> void:
	hover_ended.emit()

func _on_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not mouse_event or not mouse_event.pressed: return

	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		left_clicked.emit()
		parent_control.accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit()
		parent_control.accept_event()
