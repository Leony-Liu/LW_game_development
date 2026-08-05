extends Control 

# ==========================================
# 节点绑定 (指向整理后的 MainVBoxContainer)
# ==========================================
@onready var hp_label = %HP
@onready var stamina_label = %Stanima
@onready var mana_label = %Mana
@onready var defence_label = %Defence
@onready var shield_label = %Shield
@onready var staminars_label = %Stamina_RS
@onready var manars_label = %Mana_RS

@onready var player_buff_container = %PlayerBuffContainer
@onready var enemy_buff_container = %EnemyBuffContainer

func _ready():
	# 1. 默认隐藏，不干扰极简赛博主 UI
	self.hide()
	
	# 2. 监听全局事件总线，连接到对应的更新函数
	BattleBus.player_hp_changed.connect(update_hp)
	BattleBus.player_stamina_changed.connect(update_stamina)
	BattleBus.player_staminars_changed.connect(update_staminars)
	BattleBus.player_mana_changed.connect(update_mana)
	BattleBus.player_manars_changed.connect(update_manars)
	BattleBus.player_defence_changed.connect(update_defence)
	BattleBus.player_shield_changed.connect(update_shield)
	
	BattleBus.player_buffs_changed.connect(update_player_buffs)
	BattleBus.enemy_buffs_changed.connect(update_enemy_buffs)

# ==========================================
# F3 快捷键显隐切换 (硬核数据终端面板)
# ==========================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		self.visible = !self.visible

# ==========================================
# 基础属性更新
# ==========================================
func update_hp(current_hp: float, max_hp: float):
	hp_label.text = "HP: %d / %d" % [current_hp, max_hp]

func update_stamina(current_stamina: int, max_stamina: int):
	stamina_label.text = "SP: %d / %d" % [current_stamina, max_stamina]

func update_staminars(current_stamina_recover_speed: float):
	staminars_label.text = "SP_RS: %d" % [current_stamina_recover_speed]
	
func update_mana(current_mana: int, max_mana: int):
	mana_label.text = "MP: %d / %d" % [current_mana, max_mana]

func update_manars(current_mana_recover_speed: float):
	mana_label.text = "MP_RS: %d" % [current_mana_recover_speed]

func update_defence(current_defence: float):
	defence_label.text = "DEF: %d" % [current_defence]

func update_shield(current_shield: float):
	shield_label.text = "SHIELD: %d" % [current_shield]
	
# ==========================================
# Buff 列表动态刷新 (保留头部标题机制)
# ==========================================
func update_player_buffs(buffs: Dictionary):
	# 1. 核心修改：获取所有子节点，但从索引 1 开始遍历清除旧数据
	# 这样就完美保住了索引 0 的 "PlayerBuff:" 标题
	var children = player_buff_container.get_children()
	for i in range(1, children.size()): 
		children[i].queue_free() 
		
	# 2. 遍历字典生成新标签
	for buff_id in buffs:
		var lbl = Label.new()
		lbl.text = "[ %s ] : %s" % [buff_id, str(buffs[buff_id]["value"])]
		
		# --- 样式调整部分 ---
		lbl.add_theme_color_override("font_color", Color.GREEN_YELLOW)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.custom_minimum_size = Vector2(0, 20) 
		
		player_buff_container.add_child(lbl)

func update_enemy_buffs(buffs: Dictionary):
	# 1. 同理，保住索引 0 的 "EnemyBuff:" 标题
	var children = enemy_buff_container.get_children()
	for i in range(1, children.size()):
		children[i].queue_free()
		
	# 2. 遍历字典生成新标签
	for buff_id in buffs:
		var lbl = Label.new()
		lbl.text = "[ %s ] : %s" % [buff_id, str(buffs[buff_id]["value"])]
		
		# --- 样式调整部分 ---
		lbl.add_theme_color_override("font_color", Color.GREEN_YELLOW)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.custom_minimum_size = Vector2(0, 20) 
		
		enemy_buff_container.add_child(lbl)
