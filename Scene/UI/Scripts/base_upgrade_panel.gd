extends Control

# --- View 1 节点 ---
@onready var view1_weapon = %View1_WeaponSelect
@onready var view2_refine = %View2_CardRefine

@onready var v1_card_grid = %V1_CardGrid
@onready var v1_weapon_desc = %V1_WeaponDesc
@onready var btn_refine = %Btn_Refine
@onready var v1_weapon_grid = %V1_WeaponGrid

# --- View 2 节点 ---
@onready var v2_equipped_grid = %V2_EquippedGrid
@onready var v2_pool_grid = %V2_PoolGrid
@onready var v2_card_desc = %V2_CardDesc

@onready var btn_confirm = %Btn_ConfirmRefine
@onready var btn_cancel = %Btn_CancelRefine

var base_card_scene = preload("res://Scene/UI/base_card_item.tscn")

# 满足你的需求：只保留锈蚀砍刀，清空初始携带，每种牌配 4 张备用
var mock_weapons = [
	{
		"uid": "w_001",
		"name": "锈蚀砍刀",
		"desc": "一把饱经风霜的破旧砍刀，但依然致命。\n\n基础攻击力：15",
		"equipped_cards": [], # 初始携带清空
		"card_pool": [
			10001, 10001, 10001, 10001,
			10002, 10002, 10002, 10002,
			10003, 10003, 10003, 10003,
			10004, 10004, 10004, 10004,
			10005, 10005, 10005, 10005,
			20001, 20001, 20001, 20001,
			20002, 20002, 20002, 20002
		]
	}
]

var current_weapon_data: Dictionary = {}
var temp_equipped_cards: Array = [] # 暂存数组，用于在确认前保存玩家的修改
var max_deck_size: int = 15

func _ready() -> void:
	view1_weapon.show()
	view2_refine.hide()
	
	btn_refine.pressed.connect(_on_btn_refine_pressed)
	btn_confirm.pressed.connect(_on_btn_confirm_pressed)
	btn_cancel.pressed.connect(_on_btn_cancel_pressed)
	
	_render_weapon_list()

# ==========================================
# 视图 1：武器选择
# ==========================================
func _render_weapon_list():
	for child in v1_weapon_grid.get_children(): child.queue_free()
		
	for weapon in mock_weapons:
		var btn = Button.new()
		btn.text = weapon["name"]
		btn.custom_minimum_size = Vector2(80, 80)
		btn.pressed.connect(_on_weapon_selected.bind(weapon))
		v1_weapon_grid.add_child(btn)

func _on_weapon_selected(weapon_data: Dictionary):
	current_weapon_data = weapon_data
	v1_weapon_desc.text = weapon_data["desc"]
	
	for child in v1_card_grid.get_children(): child.queue_free()
		
	for card_id in weapon_data["equipped_cards"]:
		var card_ui = base_card_scene.instantiate()
		v1_card_grid.add_child(card_ui)
		card_ui.setup(card_id, true)

func _on_btn_refine_pressed():
	if current_weapon_data.is_empty(): return
	
	# 进入精炼时，克隆当前武器的牌组数据到暂存区
	temp_equipped_cards = current_weapon_data["equipped_cards"].duplicate()
	
	view1_weapon.hide()
	view2_refine.show()
	_refresh_refine_grids()

# ==========================================
# 视图 2：卡牌精炼 (使用 temp_equipped_cards)
# ==========================================
func _refresh_refine_grids():
	for child in v2_equipped_grid.get_children(): child.queue_free()
	for child in v2_pool_grid.get_children(): child.queue_free()
		
	# 计算备用池：总池子 减去 暂存区里的牌
	var unequipped_pool = current_weapon_data["card_pool"].duplicate()
	for id in temp_equipped_cards:
		if unequipped_pool.has(id):
			unequipped_pool.erase(id) 
			
	# 渲染左侧 (携带区 - 使用暂存数据)
	for card_id in temp_equipped_cards:
		var card_ui = base_card_scene.instantiate()
		v2_equipped_grid.add_child(card_ui)
		card_ui.setup(card_id, true)
		card_ui.card_interacted.connect(_on_card_interacted)
		
	# 渲染右侧 (备用区)
	for card_id in unequipped_pool:
		var card_ui = base_card_scene.instantiate()
		v2_pool_grid.add_child(card_ui)
		card_ui.setup(card_id, false)
		card_ui.card_interacted.connect(_on_card_interacted)

func _on_card_interacted(card_id: int, click_type: String, is_equipped: bool):
	if click_type == "left_click":
		var card_info = CardDataBase.get_card(card_id)
		# 提取 CSV 中的伤害、段数等数据展示
		var damage = card_info.get("damage", 0)
		var hits = card_info.get("hit_count", 1)
		v2_card_desc.text = "卡名: %s\n类型: %s\n单发伤害: %d\n攻击段数: %d" % [tr(card_info.get("name_key", "未知")), card_info.get("categories", "通用"), damage, hits]
		
	elif click_type == "right_click":
		if is_equipped:
			temp_equipped_cards.erase(card_id) # 卸下
		else:
			if temp_equipped_cards.size() < max_deck_size:
				temp_equipped_cards.append(card_id) # 装备
		_refresh_refine_grids()

# ==========================================
# 确认与取消逻辑
# ==========================================
func _on_btn_confirm_pressed() -> void:
	# 1. 覆盖正式数据
	current_weapon_data["equipped_cards"] = temp_equipped_cards.duplicate()
	
	# 2. 保存并同步到战斗系统
	_save_deck_to_manager()
	
	# 3. 可以在此处调用存档机制 (如需热更存档，未来可在此补充)
	# SaveManager.overwrite_save(SaveManager.current_save_id, PlayerInventory.get_data())
	
	# 4. 退回 View1
	view2_refine.hide()
	view1_weapon.show()
	_on_weapon_selected(current_weapon_data) # 刷新显示

func _on_btn_cancel_pressed() -> void:
	# 放弃暂存修改，直接退回
	view2_refine.hide()
	view1_weapon.show()

# 同步字典数据到出牌管家
func _save_deck_to_manager() -> void:
	var new_deck_config = {}
	for card_id in current_weapon_data["equipped_cards"]:
		if new_deck_config.has(card_id):
			new_deck_config[card_id] += 1
		else:
			new_deck_config[card_id] = 1
			
	PlayerDeckManager.starter_deck_config = new_deck_config
	PlayerDeckManager.generate_deck() 
	print("已同步牌组到战斗系统：", new_deck_config)
