extends Control # 或者你根节点的实际类型，比如 CanvasLayer/MarginContainer

@onready var hp_label = $MarginContainer/VBoxContainer/HP
@onready var stamina_label = $MarginContainer/VBoxContainer/Stanima
@onready var mana_label = $MarginContainer/VBoxContainer/Mana
@onready var defence_label = $MarginContainer/VBoxContainer/Defence
@onready var shield_label = $MarginContainer/VBoxContainer/Shield
@onready var staminars_label = $MarginContainer/VBoxContainer/Stamina_RS
@onready var manars_label = $MarginContainer/VBoxContainer/Mana_RS

@onready var player_buff_container = $PlayerBuff/VBoxContainer
@onready var enemy_buff_container = $EnemyBuff/VBoxContainer

func _ready():
	# 监听全局事件总线，连接到对应的更新函数
	BattleBus.player_hp_changed.connect(update_hp)
	BattleBus.player_stamina_changed.connect(update_stamina)
	BattleBus.player_staminars_changed.connect(update_staminars)
	BattleBus.player_mana_changed.connect(update_mana)
	BattleBus.player_manars_changed.connect(update_manars)
	BattleBus.player_defence_changed.connect(update_defence)
	BattleBus.player_shield_changed.connect(update_shield)
	
	BattleBus.player_buffs_changed.connect(update_player_buffs)
	BattleBus.enemy_buffs_changed.connect(update_enemy_buffs)
# --- 定义接收信号后执行的更新函数 ---

func update_hp(current_hp: float, max_hp: float):
	hp_label.text = "HP: %d / %d" % [current_hp, max_hp]

func update_stamina(current_stamina: int, max_stamina: int):
	# 注意参数名与你信号定义的保持了一致
	stamina_label.text = "SP: %d / %d" % [current_stamina, max_stamina]

func update_staminars(current_stamina_recover_speed: float):
	# 注意参数名与你信号定义的保持了一致
	staminars_label.text = "SP_RS: %d" % [current_stamina_recover_speed]
	
func update_mana(current_mana: int, max_mana: int):
	mana_label.text = "MP: %d / %d" % [current_mana, max_mana]

func update_manars(current_mana_recover_speed: float):
	mana_label.text = "MP_RS: %d" % [current_mana_recover_speed]

func update_defence(current_defence: float):
	# 修复：指向正确的 defence_label，并修改前缀
	defence_label.text = "DEF: %d" % [current_defence]

func update_shield(current_shield: float):
	# 修复：指向正确的 shield_label，并修改前缀
	shield_label.text = "SHIELD: %d" % [current_shield]
	
# ==========================================
# Buff 列表动态刷新
# ==========================================
func update_player_buffs(buffs: Dictionary):
	# 1. 清空旧列表
	for child in player_buff_container.get_children():
		child.queue_free()
		
	# 2. 遍历字典生成新标签
	for buff_id in buffs:
		var lbl = Label.new()
		
		# --- 样式调整部分 ---
		lbl.text = "[ %s ] : %s" % [buff_id, str(buffs[buff_id]["value"])]
		
		# 设置字体颜色
		lbl.add_theme_color_override("font_color", Color.GREEN_YELLOW)
		
		# 设置字体大小 (单位：像素)
		# 注意：你需要确保你的项目中有设置好基础字体，否则这里调整大小会比较模糊
		lbl.add_theme_font_size_override("font_size", 16)
		
		# 设置文本对齐方式
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# 设置内边距 (可选，如果 Buff 列表比较挤，可以加一点外边距)
		# Godot 的 Label 没有直接的 margin 属性，可以通过设置最小尺寸或容器间距实现
		lbl.custom_minimum_size = Vector2(0, 20) 
		
		player_buff_container.add_child(lbl)

func update_enemy_buffs(buffs: Dictionary):
	# 1. 清空旧列表
	for child in enemy_buff_container.get_children():
		child.queue_free()
		
	# 2. 遍历字典生成新标签
	for buff_id in buffs:
		var lbl = Label.new()
		
		# --- 样式调整部分 ---
		lbl.text = "[ %s ] : %s" % [buff_id, str(buffs[buff_id]["value"])]
		
		# 设置字体颜色
		lbl.add_theme_color_override("font_color", Color.GREEN_YELLOW)
		
		# 设置字体大小 (单位：像素)
		# 注意：你需要确保你的项目中有设置好基础字体，否则这里调整大小会比较模糊
		lbl.add_theme_font_size_override("font_size", 16)
		
		# 设置文本对齐方式
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# 设置内边距 (可选，如果 Buff 列表比较挤，可以加一点外边距)
		# Godot 的 Label 没有直接的 margin 属性，可以通过设置最小尺寸或容器间距实现
		lbl.custom_minimum_size = Vector2(0, 20) 
		
		player_buff_container.add_child(lbl)
