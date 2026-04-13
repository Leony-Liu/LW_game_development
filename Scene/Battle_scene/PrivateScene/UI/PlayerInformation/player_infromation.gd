extends Control # 或者你根节点的实际类型，比如 CanvasLayer/MarginContainer

# 获取三个 Label 节点的引用
@onready var hp_label = $MarginContainer/VBoxContainer/HP
@onready var stamina_label = $MarginContainer/VBoxContainer/Stanima
@onready var mana_label = $MarginContainer/VBoxContainer/Mana


func _ready():
	# 监听全局事件总线，连接到对应的更新函数
	EventBus.player_hp_changed.connect(update_hp)
	EventBus.player_stamina_changed.connect(update_stamina)
	EventBus.player_mana_changed.connect(update_mana)
	
	
# --- 定义接收信号后执行的更新函数 ---

func update_hp(current_hp: float, max_hp: float):
	hp_label.text = "HP: %d / %d" % [current_hp, max_hp]

func update_stamina(current_stamina: int, max_stamina: int):
	# 注意参数名与你信号定义的保持了一致
	stamina_label.text = "SP: %d / %d" % [current_stamina, max_stamina]

func update_mana(current_mana: int, max_mana: int):
	mana_label.text = "MP: %d / %d" % [current_mana, max_mana]
