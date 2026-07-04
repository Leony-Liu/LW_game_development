extends CanvasLayer
class_name ContextActionMenu

# 告诉外部玩家点击了什么操作
signal action_selected(uid: String, action_type: String, target_slot: String)

@onready var click_blocker: Control = $ClickBlocker
@onready var menu_panel: PanelContainer = $MenuPanel
@onready var action_list: VBoxContainer = $MenuPanel/MarginContainer/ActionList

var current_uid: String = ""

func _ready() -> void:
	self.hide()
	# 监听全屏透明遮罩的点击事件
	click_blocker.gui_input.connect(_on_blocker_gui_input)

# ==== 唤出菜单的核心方法 ====
# trigger_pos: 弹出位置(通常是物品列表按钮的 global_position)
# uid: 物品唯一ID
# actions: 要生成的按钮配置字典，例如 [{"text": "装备", "type": "equip", "slot": "weapon_1"}]
func show_menu(trigger_pos: Vector2, uid: String, actions: Array) -> void:
	current_uid = uid
	
	# 1. 清空旧按钮
	for child in action_list.get_children():
		child.queue_free()
		
	# 2. 生成新按钮
	for act in actions:
		var btn = Button.new()
		btn.text = act["text"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.theme_type_variation = "ListButton" # 套用你配置好的废土主题
		
		# 点击某个选项后，发出信号，并立刻关闭菜单
		btn.pressed.connect(func(): 
			action_selected.emit(current_uid, act["type"], act["slot"])
			hide_menu()
		)
		action_list.add_child(btn)
	
	# 3. 设定坐标：让菜单贴在点击的物品的右下角或旁边
	# 注意：实际项目中可能需要加个偏移量，比如 trigger_pos + Vector2(20, 20)
	menu_panel.global_position = trigger_pos
	
	# 4. 显示自己
	self.show()

# ==== 关闭逻辑 ====
func hide_menu() -> void:
	self.hide()
	current_uid = ""

func _on_blocker_gui_input(event: InputEvent) -> void:
	# 只要玩家在屏幕上的非菜单区域按下了鼠标（左键或右键），立刻关闭菜单
	if event is InputEventMouseButton and event.pressed:
		hide_menu()
