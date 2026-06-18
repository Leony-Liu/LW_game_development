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
var real_weapons: Array = []

var current_weapon_data: Dictionary = {}
var temp_equipped_cards: Array = [] # 暂存数组，用于在确认前保存玩家的修改
var max_deck_size: int = 15

func _ready() -> void:
	view1_weapon.show()
	view2_refine.hide()
	
	# 【新增】：开局隐藏确认和取消按钮
	btn_confirm.hide() 
	btn_cancel.hide()  
	
	btn_refine.pressed.connect(_on_btn_refine_pressed)
	btn_confirm.pressed.connect(_on_btn_confirm_pressed)
	btn_cancel.pressed.connect(_on_btn_cancel_pressed)
	
	if SaveManager.current_save.has("weapons"):
		real_weapons = SaveManager.current_save["weapons"]
	else:
		print("警告：该存档中未检测到 weapons 数据，可能是老存档。")
		
	_render_weapon_list()

# ==========================================
# 视图 1：武器选择
# ==========================================
func _render_weapon_list():
	for child in v1_weapon_grid.get_children(): child.queue_free()
	
	# 【修改】：遍历 real_weapons
	for weapon in real_weapons:
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
	
	btn_confirm.show() 
	btn_cancel.show() 
	
	_refresh_refine_grids()

# ==========================================
# 视图 2：卡牌精炼 (物理转移重构版)
# ==========================================

func _refresh_refine_grids():
	# 1. 进场时只做一次彻底清空
	for child in v2_equipped_grid.get_children(): child.queue_free()
	for child in v2_pool_grid.get_children(): child.queue_free()
	
	# 2. 计算备用池：总池子 减去 已装备的牌
	var unequipped_pool = current_weapon_data["card_pool"].duplicate()
	
	# 3. 渲染左侧 (携带区)
	for card_id in temp_equipped_cards:
		if unequipped_pool.has(card_id):
			unequipped_pool.erase(card_id) # 从备用池中划掉这张已装备的牌
			
		var card_ui = base_card_scene.instantiate()
		v2_equipped_grid.add_child(card_ui)
		card_ui.setup(card_id, true)
		# 🌟【核心改变】：使用 bind 把卡牌节点自己 (card_ui) 传给交互函数
		card_ui.card_interacted.connect(_on_card_interacted.bind(card_ui))
		
	# 4. 渲染右侧 (备用区)
	for card_id in unequipped_pool:
		var card_ui = base_card_scene.instantiate()
		v2_pool_grid.add_child(card_ui)
		card_ui.setup(card_id, false)
		# 🌟同样绑定节点自身
		card_ui.card_interacted.connect(_on_card_interacted.bind(card_ui))

# 注意这里的参数多了一个 card_node: Control
func _on_card_interacted(card_id: int, click_type: String, is_equipped: bool, card_node: Control):
	if click_type == "left_click":
		# 左键：查看详情
		var card_info = CardDataBase.get_card(card_id)
		var damage = card_info.get("damage", 0)
		var hits = card_info.get("hit_count", 1)
		v2_card_desc.text = "卡名: %s\n类型: %s\n单发伤害: %d\n攻击段数: %d" % [tr(card_info.get("name_key", "未知")), card_info.get("categories", "通用"), damage, hits]
		
	elif click_type == "right_click":
		# 右键：🌟【真实物理转移节点】绝对体现“每张牌的唯一性”
		if card_node.get_parent() == v2_equipped_grid:
			# 如果它现在在左边 -> 从携带区卸下，物理移动到右边(备用区)
			card_node.reparent(v2_pool_grid)
			card_node.is_in_equipped_zone = false
			
		elif card_node.get_parent() == v2_pool_grid:
			# 如果它现在在右边 -> 从备用区装备，物理移动到左边(携带区)
			if v2_equipped_grid.get_child_count() < max_deck_size:
				card_node.reparent(v2_equipped_grid)
				card_node.is_in_equipped_zone = true
			else:
				print("携带区已满，无法装备更多卡牌！")

func _on_btn_confirm_pressed() -> void:
	# 🌟【全新保存逻辑】：直接读取左侧容器里真实存在的卡牌节点！
	# 所见即所得，界面里摆了什么，我们就存什么。
	temp_equipped_cards.clear()
	for card_node in v2_equipped_grid.get_children():
		temp_equipped_cards.append(card_node.card_id)
		
	# 覆盖正式数据
	current_weapon_data["equipped_cards"] = temp_equipped_cards.duplicate()
	
	# 同步给战斗大管家并写入硬盘存档
	_save_deck_to_manager()
	SaveManager.save_current_state()
	
	# 退回武器选择界面并隐藏底部按钮
	view2_refine.hide()
	view1_weapon.show()
	btn_confirm.hide()
	btn_cancel.hide()
	
	_on_weapon_selected(current_weapon_data)

# ==========================================
# 确认与取消逻辑
# ==========================================


func _on_btn_cancel_pressed() -> void:
	view2_refine.hide()
	view1_weapon.show()
	
	# 【新增】：取消并退回界面1时，隐藏这两个按钮
	btn_confirm.hide()
	btn_cancel.hide()

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
