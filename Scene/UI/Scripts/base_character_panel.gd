extends Control

# ==========================================
# 场景跳转配置
# ==========================================
@export_category("Level Navigation")
@export var target_map_world: PackedScene 
@export var target_map_ui: PackedScene 

@onready var enter_map_btn = $MarginContainer/Button
@onready var category_tabs = $MarginContainer2/HBoxContainer/Right_BackpackPanelMargin/Right_BackpackPanel/CategoryTabs

# ==========================================
# 状态与精细化假数据 (Mock Data)
# ==========================================
var current_selected_item: Dictionary = {}
var current_category: String = "weapon" # 记住当前打开的是哪个分类 Tab

# 🌟【数据升级】：
# 1. 增加了 equip_type 用于严格校验槽位（比如 armor 分类下具体是 helmet 还是 chest）
# 2. 增加了 is_equipped 用于判断是否要从背包中隐藏
# 3. 增加了 count 用于模拟道具堆叠
var mock_inventory = [
	{"uid": "w1", "name": "生锈铁剑", "type": "weapon", "equip_type": "weapon", "is_equipped": false, "desc": "攻击力: 10\n自带卡组: 重击x3"},
	{"uid": "w2", "name": "骑士长枪", "type": "weapon", "equip_type": "weapon", "is_equipped": false, "desc": "攻击力: 15\n自带卡组: 突刺x2"},
	{"uid": "a1", "name": "铁头盔", "type": "armor", "equip_type": "helmet", "is_equipped": false, "desc": "防御力: 3\n保护你的脑袋。"},
	{"uid": "a2", "name": "破旧皮甲", "type": "armor", "equip_type": "chest", "is_equipped": false, "desc": "防御力: 5\n重量: 轻"},
	{"uid": "i1", "name": "治疗药水", "type": "item", "equip_type": "item", "is_equipped": false, "count": 3, "desc": "恢复 50 点生命值。"},
	{"uid": "i2", "name": "磨刀石", "type": "item", "equip_type": "item", "is_equipped": false, "count": 1, "desc": "下一次攻击伤害提升。"}
]

func _ready() -> void:
	if enter_map_btn:
		enter_map_btn.pressed.connect(_on_enter_map_pressed)
		
	# 1. 绑定分类 Tab 
	for tab in category_tabs.get_children():
		if tab is Button:
			tab.pressed.connect(_on_tab_pressed.bind(tab.name.to_lower()))
			
	# 2. 🌟【核心升级：严格绑定槽位类型】
	# 防具槽位：将自身的名字(转小写)作为限定类型，例如 "Helmet" -> "helmet"
	for slot in %ArmorSlots.get_children():
		if slot is Button:
			slot.pressed.connect(_on_equip_slot_pressed.bind(slot.name.to_lower(), slot))
			
	# 武器和道具槽位：因为可以随便放，所以统一用 "weapon" 和 "item"
	for slot in %WeaponSlots.get_children():
		if slot is Button:
			slot.pressed.connect(_on_equip_slot_pressed.bind("weapon", slot))
			
	for slot in %itemSlots.get_children():
		if slot is Button:
			slot.pressed.connect(_on_equip_slot_pressed.bind("item", slot))
		
	_clear_detail()
	_render_inventory(current_category)

# ==========================================
# 右侧：背包分类与渲染 (自动隐藏已装备物品)
# ==========================================
func _on_tab_pressed(category_type: String) -> void:
	current_category = category_type
	_render_inventory(category_type)
	_clear_detail() # 切换分类时清空选中状态，防误触

func _render_inventory(category_type: String) -> void:
	var grid = get_node_or_null("%InventoryGrid")
	if not grid: return
		
	for child in grid.get_children():
		child.queue_free()
	
	for item in mock_inventory:
		if typeof(item) != TYPE_DICTIONARY or not item.has("type"): continue
		
		# 🌟【核心逻辑】：如果已经穿在身上了，就不在背包里显示！
		if item.get("is_equipped", false) == true: continue
			
		if item["type"] == category_type:
			var btn = Button.new()
			# 🌟【叠加逻辑】：如果有 count 属性且大于 1，则显示数量
			var display_name = item.get("name", "未知物品")
			if item.has("count") and item["count"] > 1:
				display_name += " x" + str(item["count"])
				
			btn.text = display_name
			btn.custom_minimum_size = Vector2(80, 80) 
			btn.pressed.connect(_on_inventory_item_pressed.bind(item))
			grid.add_child(btn)

# ==========================================
# 中间：选中背包物品查看详情
# ==========================================
func _on_inventory_item_pressed(item: Dictionary) -> void:
	current_selected_item = item
	%DetailName.text = item.get("name", "未知名称")
	%DetailType.text = "类型: " + item.get("equip_type", "未知")
	%DetailDesc.text = item.get("desc", "无描述")

func _clear_detail() -> void:
	current_selected_item = {}
	%DetailName.text = "未选择物品"
	%DetailType.text = ""
	%DetailDesc.text = "请在右侧背包中选择一个物品查看详情。\n(直接点击已装备的槽位可卸下物品)"

# ==========================================
# 左侧：点击槽位进行穿戴 / 卸下
# ==========================================
func _on_equip_slot_pressed(slot_required_type: String, slot_node: Button) -> void:
	# 检查这个槽位目前是不是已经穿了东西（通过 Godot 的 meta 存 UID）
	var current_equipped_uid = slot_node.get_meta("equipped_uid", "")
	
	# ========================================
	# 逻辑 A：手里没拿东西 -> 尝试卸下当前槽位的装备
	# ========================================
	if current_selected_item.is_empty():
		if current_equipped_uid != "":
			_set_item_equipped_status(current_equipped_uid, false) # 改回未装备状态
			slot_node.text = slot_node.name # 按钮文字恢复默认名字(如 "Helmet")
			slot_node.set_meta("equipped_uid", "") # 清空槽位记忆
			print("已卸下装备，放回背包。")
			_render_inventory(current_category) # 刷新背包，物品重新出现
		return
		
	# ========================================
	# 逻辑 B：手里有东西 -> 尝试穿戴或替换
	# ========================================
	# 🌟【严格校验】：比如拿着 "weapon"，点到了 "helmet" 槽位，直接拦截！
	if current_selected_item.get("equip_type") != slot_required_type:
		print("❌ 类型不匹配！[%s] 不能放在 [%s] 槽位！" % [current_selected_item.get("name"), slot_required_type])
		return
		
	# 如果槽位上本来就有东西，先把旧的卸下来放回背包
	if current_equipped_uid != "":
		_set_item_equipped_status(current_equipped_uid, false)
		
	# 穿上新装备
	current_selected_item["is_equipped"] = true
	
	# 更新 UI 显示 (如果是多数量道具，带上数量)
	var display_name = current_selected_item["name"]
	if current_selected_item.has("count") and current_selected_item["count"] > 1:
		display_name += " x" + str(current_selected_item["count"])
		
	slot_node.text = display_name
	slot_node.set_meta("equipped_uid", current_selected_item["uid"]) # 让槽位记住穿的是谁
	
	print("✅ 已成功装备：" + current_selected_item["name"])
	
	# 清空选中状态并刷新背包(让刚穿上的装备从背包消失)
	_clear_detail()
	_render_inventory(current_category)

# 辅助函数：根据 UID 修改库里物品的装备状态
func _set_item_equipped_status(uid: String, status: bool) -> void:
	for item in mock_inventory:
		if item.get("uid") == uid:
			item["is_equipped"] = status
			return

# ==========================================
# 底部：进入地图
# ==========================================
func _on_enter_map_pressed() -> void:
	if not target_map_world or not target_map_ui: return
	var main_root = get_tree().root.get_node_or_null("MAIN")
	if main_root:
		SceneManager.transition_to(func(): main_root.load_combat_scene(target_map_world, target_map_ui), 0.5)
