extends Control
# base_character_panel.gd

@export_category("Level Navigation")
@export var target_map_world: PackedScene
@export var target_map_ui: PackedScene

@onready var enter_map_btn = $MarginContainer/Button
@onready var category_tabs = $MarginContainer2/HBoxContainer/Right_BackpackPanelMargin/Right_BackpackPanel/CategoryTabs

var current_selected_uid: String = ""
var current_category: String = "weapon"

const BACKPACK_MAX_SLOTS: int = 20 # 角色界面的背包网格容量（可根据你的行列数修改）

func _ready() -> void:
	if enter_map_btn:
		enter_map_btn.pressed.connect(_on_enter_map_pressed)
	
	# 1. 绑定分类 Tab
	if category_tabs:
		for tab in category_tabs.get_children():
			if tab is Button:
				tab.pressed.connect(_on_tab_pressed.bind(tab.name.to_lower()))
	
	# 2. 动态绑定槽位并注入 (允许装配的分类, 专属Location标签)
	if get_node_or_null("%ArmorSlots"):
		for slot in %ArmorSlots.get_children():
			if slot is Button:
				var loc_name = "equipped_" + slot.name.to_lower()
				slot.pressed.connect(_on_equip_slot_pressed.bind("armor", loc_name, slot))
	
	if get_node_or_null("%WeaponSlots"):
		for slot in %WeaponSlots.get_children():
			if slot is Button:
				var loc_name = "equipped_" + slot.name.to_lower()
				slot.pressed.connect(_on_equip_slot_pressed.bind("weapon", loc_name, slot))
	
	if get_node_or_null("%itemSlots"):
		for slot in %itemSlots.get_children():
			if slot is Button:
				var loc_name = "equipped_" + slot.name.to_lower()
				slot.pressed.connect(_on_equip_slot_pressed.bind("item", loc_name, slot))
	
	_clear_detail()
	_refresh_all()

# --- 渲染刷新逻辑 ---
func _refresh_all() -> void:
	_render_inventory(current_category)
	_render_equipped_slots()

func _on_tab_pressed(category_type: String) -> void:
	current_category = category_type
	_render_inventory(category_type)
	_clear_detail()

# 【核心修复】：安全清空节点引擎
func _clear_grid_safely(grid: Container) -> void:
	for child in grid.get_children():
		grid.remove_child(child) 
		child.queue_free()

func _render_inventory(category_type: String) -> void:
	var grid = get_node_or_null("%InventoryGrid")
	if not grid: return
	
	_clear_grid_safely(grid)
	
	# 向管家索要对应分类的背包物品
	var backpack_items = InventoryManager.get_items("backpack", category_type)
	
	# 使用全新的 Figma 浅灰质感填充
	for i in range(BACKPACK_MAX_SLOTS):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(150, 140) # 统一150x140规格
		btn.focus_mode = Control.FOCUS_NONE
		
		# --- 创建完全匹配 Figma 草稿的浅灰色实体背景 ---
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color("d9d9d9") # 浅灰占位色
		style_box.border_color = Color("aaaaaa")
		style_box.border_width_bottom = 2
		style_box.border_width_right = 2
		
		btn.add_theme_stylebox_override("normal", style_box)
		btn.add_theme_stylebox_override("hover", style_box)
		btn.add_theme_stylebox_override("disabled", style_box)
		
		if i < backpack_items.size():
			var item = backpack_items[i]
			var static_data = ItemDatabaseManager.get_item_data(item["template_id"])
			if static_data.is_empty(): continue
			
			var display_name = tr(static_data.get("name_key", "未知物品"))
			if item.has("count") and item["count"] > 1:
				display_name += "\nx" + str(item["count"])
			
			if item.get("is_broken", false):
				btn.add_theme_color_override("font_color", Color.RED)
				display_name += "\n(破损)"
			else:
				btn.add_theme_color_override("font_color", Color("1a1a1a")) # 浅灰底配深色字
			
			btn.text = display_name
			btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			
			# 绑定角色面板专属的装备替换信号
			btn.pressed.connect(_on_inventory_item_pressed.bind(item["uid"], static_data, item))
		else:
			# 空槽位
			btn.text = ""
			btn.disabled = true
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.modulate = Color.WHITE
			
		grid.add_child(btn)

func _render_equipped_slots() -> void:
	var all_slot_containers = []
	if get_node_or_null("%ArmorSlots"): all_slot_containers.append(%ArmorSlots)
	if get_node_or_null("%WeaponSlots"): all_slot_containers.append(%WeaponSlots)
	if get_node_or_null("%itemSlots"): all_slot_containers.append(%itemSlots)
	
	for container in all_slot_containers:
		for slot in container.get_children():
			if slot is Button:
				var loc_name = "equipped_" + slot.name.to_lower()
				var items_in_slot = InventoryManager.get_items(loc_name)
				
				if items_in_slot.size() > 0:
					var item = items_in_slot[0]
					var static_data = ItemDatabaseManager.get_item_data(item["template_id"])
					var d_name = tr(static_data.get("name_key", "未知"))
					
					if item.has("count") and item["count"] > 1:
						d_name += " x" + str(item["count"])
					
					slot.text = d_name
					slot.set_meta("equipped_uid", item["uid"])
					
					if item.get("is_broken", false):
						slot.add_theme_color_override("font_color", Color.RED)
					else:
						slot.remove_theme_color_override("font_color")
				else:
					slot.text = slot.name
					slot.set_meta("equipped_uid", "")
					slot.remove_theme_color_override("font_color")

# --- 交互逻辑 ---
func _on_inventory_item_pressed(uid: String, static_data: Dictionary, dynamic_data: Dictionary) -> void:
	current_selected_uid = uid
	if get_node_or_null("%DetailName"):
		%DetailName.text = tr(static_data.get("name_key", "未知名称"))
		
	if get_node_or_null("%DetailType"):
		var specific_type = static_data.get("equip_type", static_data.get("wep_type", "通用"))
		%DetailType.text = "类型: " + specific_type
		
	if get_node_or_null("%DetailDesc"):
		var desc = tr(static_data.get("desc", "无描述"))
		if dynamic_data.has("current_durability"):
			desc += "\n耐久度: %d / %d" % [dynamic_data["current_durability"], static_data.get("max_durability", 100)]
		%DetailDesc.text = desc

func _clear_detail() -> void:
	current_selected_uid = ""
	if get_node_or_null("%DetailName"): %DetailName.text = "未选择物品"
	if get_node_or_null("%DetailType"): %DetailType.text = ""
	if get_node_or_null("%DetailDesc"): %DetailDesc.text = "请在右侧选择物品查看详情。\n(点击已装备槽位可卸下)"

func _on_equip_slot_pressed(required_category: String, target_location: String, slot_node: Button) -> void:
	var current_equipped_uid = slot_node.get_meta("equipped_uid", "")
	
	# 情况 A：手里没拿东西 -> 卸下当前槽位的装备到背包
	if current_selected_uid == "":
		if current_equipped_uid != "":
			InventoryManager.move_item(current_equipped_uid, "backpack")
			_refresh_all()
		return
		
	# 情况 B：手里拿着东西 -> 尝试穿戴/替换
	var selected_item = InventoryManager.get_item_by_uid(current_selected_uid)
	var static_data = ItemDatabaseManager.get_item_data(selected_item["template_id"])
	var item_category = static_data.get("category", "")
	
	if item_category != required_category:
		print("❌ 穿戴失败：物品类型不符。")
		return
		
	if selected_item.get("is_broken", false):
		print("❌ 穿戴失败：装备已彻底破损，需先维修！")
		return
		
	if required_category == "armor":
		var specific_type = static_data.get("equip_type", "")
		var slot_suffix = target_location.split("_")[1]
		if specific_type != slot_suffix:
			print("❌ 穿戴失败：部位不匹配 (%s 不能放在 %s)" % [specific_type, slot_suffix])
			return
			
	InventoryManager.move_item(current_selected_uid, target_location)
	_clear_detail()
	_refresh_all()

func _on_enter_map_pressed() -> void:
	if not target_map_world or not target_map_ui: return
	var main_root = get_tree().root.get_node_or_null("MAIN")
	if main_root:
		SceneManager.transition_to(func(): main_root.load_combat_scene(target_map_world, target_map_ui), 0.5)
