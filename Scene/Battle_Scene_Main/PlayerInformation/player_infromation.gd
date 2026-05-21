extends Control # 或者你根节点的实际类型，比如 CanvasLayer/MarginContainer

# 获取三个 Label 节点的引用
@onready var hp_label = $MarginContainer/VBoxContainer/HP
@onready var stamina_label = $MarginContainer/VBoxContainer/Stanima
@onready var mana_label = $MarginContainer/VBoxContainer/Mana
@onready var defence_label = $MarginContainer/VBoxContainer/Defence
@onready var shield_label = $MarginContainer/VBoxContainer/Shield
@onready var staminars_label = $MarginContainer/VBoxContainer/Stamina_RS
@onready var manars_label = $MarginContainer/VBoxContainer/Mana_RS

func _ready():
	# 监听全局事件总线，连接到对应的更新函数
	BattleBus.player_hp_changed.connect(update_hp)
	BattleBus.player_stamina_changed.connect(update_stamina)
	BattleBus.player_staminars_changed.connect(update_staminars)
	BattleBus.player_mana_changed.connect(update_mana)
	BattleBus.player_manars_changed.connect(update_manars)
	BattleBus.player_defence_changed.connect(update_defence)
	BattleBus.player_shield_changed.connect(update_shield)
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
	mana_label.text = "MP_RS: %d" % [current_defence]

func update_shield(current_defence: float):
	mana_label.text = "MP_RS: %d" % [current_defence]
