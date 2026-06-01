extends Control

# ==========================================
# 1. 变量声明与节点绑定
# ==========================================
@onready var save_list_container = $ScrollContainer/SaveListContainer 

@export_category("Navigation")
@export var base_scene: PackedScene # 修复之前未声明 base_scene 的 Bug！

@export_category("UI Sub-Panels")
@export var name_input_panel: Control # 用于打字输入名字的弹窗面板
@export var line_edit: LineEdit       # 名字输入框
@export var confirm_button: Button   # 确认新建按钮
@export var cancel_button: Button    # 取消新建按钮


@export_category("Delete Save UI")
@export var delete_confirm_panel: Control
@export var confirm_delete_btn: Button
@export var cancel_delete_btn: Button

var pending_delete_id: String = ""


func _ready() -> void:
	if name_input_panel: name_input_panel.hide()
	if delete_confirm_panel: delete_confirm_panel.hide() # 【新增】默认隐藏删除弹窗
		
	# 新建存档相关信号
	if confirm_button: confirm_button.pressed.connect(_on_confirm_create_save)
	if cancel_button: cancel_button.pressed.connect(func(): name_input_panel.hide())
	
	# 【新增】删除存档确认弹窗信号
	if confirm_delete_btn: confirm_delete_btn.pressed.connect(_on_confirm_delete_save)
	if cancel_delete_btn: cancel_delete_btn.pressed.connect(func(): delete_confirm_panel.hide())
	
	_refresh_save_list()

# ==========================================
# 2. 监听返回键 (ESC)
# ==========================================
func _unhandled_input(event: InputEvent) -> void: 
	if event.is_action_pressed("ui_cancel"): 
		_return_to_main_menu() 

func _return_to_main_menu() -> void: 
	var main_root = get_tree().root.get_node_or_null("MAIN") 
	if not main_root: return 
		
	var load_main_logic = func(): 
		var main_menu = load("res://Scene/UI/main_menu.tscn") 
		main_root.load_ui_scene(main_menu) 
		
	SceneManager.transition_to(load_main_logic, 0.5) 

# ==========================================
# 3. 核心：动态渲染整个列表（含已有存档与+号）
# ==========================================
# ==========================================
# 【修改】动态渲染列表（引入横向排版与删除按钮）
# ==========================================
func _refresh_save_list() -> void: 
	for child in save_list_container.get_children(): 
		child.queue_free() 
		
	var saves = SaveManager.get_all_saves() 
	for save_data in saves: 
		var char_name = save_data.get("name", "未知特工") 
		var save_id = save_data["id"]
		
		# 1. 创建横向容器 (HBoxContainer) 作为每一行的底座
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(500, 100)
		# 让横向容器里的元素间距大一点
		row.add_theme_constant_override("separation", 10) 
		
		# 2. 创建原本的“读取存档”按钮
		var save_btn = Button.new() 
		save_btn.text = " EMPLOYEE: " + char_name 
		# 【关键】让读取按钮占据横向容器的绝大部分空间
		save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
		save_btn.add_theme_color_override("font_color", Color("00bfff")) 
		save_btn.add_theme_font_size_override("font_size", 22) 
		save_btn.pressed.connect(_on_exist_save_clicked.bind(save_id)) 
		
		# 3. 【新增】创建“删除”小按钮
		var del_btn = Button.new()
		del_btn.text = "×"
		# 【关键】固定删除按钮的宽度
		del_btn.custom_minimum_size = Vector2(100, 0) 
		del_btn.add_theme_color_override("font_color", Color("ff4444")) # 红色警示
		del_btn.add_theme_font_size_override("font_size", 20)
		del_btn.pressed.connect(_on_delete_requested.bind(save_id))
		
		# 4. 把两个按钮都塞进这一行的横向容器里
		row.add_child(save_btn)
		row.add_child(del_btn)
		
		# 5. 把整行塞进大列表里
		save_list_container.add_child(row) 
		
	# 渲染底部的“+ 新建”按钮 (保持不变)[cite: 1]
	var new_save_btn = Button.new()
	new_save_btn.text = " + "
	new_save_btn.custom_minimum_size = Vector2(500, 100)
	new_save_btn.add_theme_color_override("font_color", Color("ff7700")) 
	new_save_btn.add_theme_font_size_override("font_size", 32)
	new_save_btn.pressed.connect(_on_new_save_slot_clicked)
	save_list_container.add_child(new_save_btn)

# ==========================================
# 【新增】删除相关的交互回调
# ==========================================
func _on_delete_requested(save_id: String) -> void:
	# 玩家点下该条目的删除键时，记录下 ID，并弹出警告框
	pending_delete_id = save_id
	if delete_confirm_panel:
		delete_confirm_panel.show()

func _on_confirm_delete_save() -> void:
	if pending_delete_id == "": return
	
	# 调用大管家物理删除文件
	SaveManager.delete_save(pending_delete_id)
	
	# 隐藏弹窗，清空记录
	delete_confirm_panel.hide()
	pending_delete_id = ""
	
	# 重新刷新列表（被删除的条目就会消失）
	_refresh_save_list()

# ==========================================
# 4. 交互响应回调
# ==========================================
func _on_exist_save_clicked(save_id: String) -> void: 
	print("UI操作：玩家点击了存档 -> ", save_id) 
	if SaveManager.load_save(save_id): 
		var main_root = get_tree().root.get_node_or_null("MAIN") 
		if main_root and base_scene: 
			var load_base_logic = func(): 
				main_root.load_world_scene(base_scene) 
			SceneManager.transition_to(load_base_logic, 0.5) 

func _on_new_save_slot_clicked() -> void:
	if name_input_panel and line_edit:
		line_edit.text = ""
		name_input_panel.show()
		line_edit.grab_focus() # 自动失焦到打字框

func _on_confirm_create_save() -> void:
	var new_name = line_edit.text.strip_edges()
	if new_name == "":
		print("警告：名字不能为空！")
		return
		
	# 呼叫大管家写入本地 JSON
	SaveManager.create_new_save(new_name)
	name_input_panel.hide()
	
	# 重新刷新列表，此时就能看到刚建好的存档和移动后的+号了！
	_refresh_save_list()
