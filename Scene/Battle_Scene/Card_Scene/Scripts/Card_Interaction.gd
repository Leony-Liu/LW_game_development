extends Node

## 鼠标进入卡牌区域时发射的局部信号
signal hover_started
## 鼠标离开卡牌区域时发射的局部信号
signal hover_ended
## 鼠标左键点击卡牌时发射的局部信号
signal left_clicked
## 鼠标右键点击卡牌时发射的局部信号
signal right_clicked

## 记录当前鼠标是否正悬停在该卡牌上方
var is_hovered: bool = false
## 获取并缓存挂载此组件的父节点（即卡牌根节点）引用
@onready var parent_card: Control = get_parent()

# 节点就绪时，主动连接父卡牌的内置鼠标与输入信号。
func _ready() -> void:
	parent_card.mouse_entered.connect(_on_mouse_entered)
	parent_card.mouse_exited.connect(_on_mouse_exited)
	parent_card.gui_input.connect(_on_gui_input)

# 捕获父节点的鼠标进入事件，更新状态并向外抛出悬停开始信号。
func _on_mouse_entered() -> void:
	is_hovered = true
	hover_started.emit()

# 捕获父节点的鼠标离开事件，更新状态并向外抛出悬停结束信号。
func _on_mouse_exited() -> void:
	is_hovered = false
	hover_ended.emit()

# 拦截父节点的输入事件，将有效的左/右键点击转化为对应的局部信号。
func _on_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not mouse_event or not mouse_event.pressed: return

	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		left_clicked.emit()
		parent_card.accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit()
		parent_card.accept_event()
