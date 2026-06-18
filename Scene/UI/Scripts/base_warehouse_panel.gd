extends Control
# base_warehouse_panel.gd

# --- 节点绑定 ---
@onready var category_tabs = %CategoryTabs
@onready var warehouse_grid = %WarehouseGrid
@onready var backpack_grid = %BackpackGrid

# 中心详情区
@onready var detail_name = %DetailName
@onready var detail_type = %DetailType
@onready var detail_desc = %DetailDesc

# --- 状态数据 ---
var current_warehouse_category: String = "weapon"
var current_selected_uid: String = ""

# --- 固定网格容量配置 (严格匹配 Figma 草稿) ---
const WAREHOUSE_MAX_SLOTS: int = 16 # 仓库: 4列 x 4行 = 16格
const BACKPACK_MAX_SLOTS: int = 12  # 背包: 3列 x 4行 = 12格

func _ready() -> void:
	if category_tabs:
		for tab in category_tabs.get_children():
			if tab is Button:
				tab.pressed.connect(_on_tab_pressed.bind(tab.name.to_lower()))
	
	_clear_detail()
	_refresh_both_sides()

func _on_tab_pressed(category: String) -> void:
	current_warehouse_category = category
	_refresh_both_sides()
	_clear_detail()

func _refresh_both_sides() -> void:
	_render_warehouse()
	_render_backpack()

# --- 渲染逻辑 ---
func _render_warehouse() -> void:
	if not warehouse_grid: return
	_clear_grid_safely(warehouse_grid)
	var items = InventoryManager.get_items("warehouse", current_warehouse_category)
	_fill_grid_with_slots(warehouse_grid, items, WAREHOUSE_MAX_SLOTS, "backpack")

func _render_backpack() -> void:
	if not backpack_grid: return
	_clear_grid_safely(backpack_grid)
	var items = InventoryManager.get_items("backpack", current_warehouse_category)
	_fill_grid_with_slots(backpack_grid, items, BACKPACK_MAX_SLOTS, "warehouse")

# 【核心修复】：安全清空节点引擎
func _clear_grid_safely(grid: Container) -> void:
	for child in grid.get_children():
		grid.remove_child(child) 
		child.queue_free()       

# 核心渲染引擎：完美还原 Figma 的 150x140 浅灰质感
func _fill_grid_with_slots(grid: GridContainer, items: Array, max_slots: int, target_location: String) -> void:
	for i in range(max_slots):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(150, 140) # 严格遵守要求的尺寸
		btn.focus_mode = Control.FOCUS_NONE
		
		# --- 创建完全匹配 Figma 草稿的浅灰色实体背景 ---
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color("d9d9d9") # Figma 常见的浅灰占位色
		style_box.border_color = Color("aaaaaa")
		style_box.border_width_bottom = 2
		style_box.border_width_right = 2
		
		# 统一应用基础样式 (无论有没有物品，底色都是这个灰块)
		btn.add_theme_stylebox_override("normal", style_box)
		btn.add_theme_stylebox_override("hover", style_box)
		btn.add_theme_stylebox_override("disabled", style_box)
		
		if i < items.size():
			var item = items[i]
			var static_data = ItemDatabaseManager.get_item_data(item["template_id"])
			var display_name = tr(static_data.get("name_key", "未知物品"))
			
			if item.has("count") and item["count"] > 1:
				display_name += "\nx" + str(item["count"])
			
			if item.get("is_broken", false):
				btn.add_theme_color_override("font_color", Color.RED)
				display_name += "\n(破损)"
			else:
				# 浅色背景配深色字更清晰
				btn.add_theme_color_override("font_color", Color("1a1a1a")) 
				
			btn.text = display_name
			btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.gui_input.connect(_on_item_gui_input.bind(item, target_location))
		else:
			btn.text = ""
			btn.disabled = true
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# 确保没有任何半透明遮挡，纯粹展示纯灰底色
			btn.modulate = Color.WHITE 
			
		grid.add_child(btn)

# --- 核心交互 ---
func _on_item_gui_input(event: InputEvent, item: Dictionary, target_location: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		var static_data = ItemDatabaseManager.get_item_data(item["template_id"])
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			current_selected_uid = item["uid"]
			detail_name.text = tr(static_data.get("name_key", "未知名称"))
			var specific_type = static_data.get("equip_type", static_data.get("wep_type", "通用"))
			detail_type.text = "类型: " + specific_type
			
			var desc = tr(static_data.get("desc", "无描述"))
			if item.has("current_durability"):
				desc += "\n\n耐久度: %d / %d" % [item["current_durability"], static_data.get("max_durability", 100)]
			detail_desc.text = desc
			
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 调用大管家转移数据，然后强制双端重绘
			InventoryManager.move_item(item["uid"], target_location)
			_clear_detail()
			_refresh_both_sides()

func _clear_detail() -> void:
	current_selected_uid = ""
	if detail_name: detail_name.text = "未选择物品"
	if detail_type: detail_type.text = ""
	if detail_desc: detail_desc.text = "左键点击物品查看详情\n右键点击物品快捷转移"
