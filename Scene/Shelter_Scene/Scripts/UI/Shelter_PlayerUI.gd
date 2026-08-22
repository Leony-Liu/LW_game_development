extends Control

# 暴露给检查器，方便美术/策划直接拖拽分配节点，代码中不写死路径
@export var character_page: Control
@export var inventory_page: Control

var is_ui_open: bool = false

func _ready() -> void:
	# 初始状态隐藏整个主界面
	hide()
	# 初始化子页面状态：默认显示背包，隐藏角色页面
	if inventory_page:
		inventory_page.show()
	if character_page:
		character_page.hide()

func _input(event: InputEvent) -> void:
	# 监听 Tab 键 (对应项目输入映射中的 open_backpack 动作)
	if event.is_action_pressed("open_backpack"):
		toggle_player_ui()

func toggle_player_ui() -> void:
	is_ui_open = !is_ui_open
	visible = is_ui_open
	
	if is_ui_open:
		# 当界面打开且显示的是背包时，通知背包页面刷新数据
		if inventory_page and inventory_page.visible and inventory_page.has_method("refresh_ui"):
			inventory_page.refresh_ui()
