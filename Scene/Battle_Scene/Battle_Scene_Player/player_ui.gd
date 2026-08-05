extends Control

@onready var current_hp_bar = %current_hp
@onready var different_hp_bar = %different_hp
@onready var show_hp = %currentHP


# 声明一个变量来存储动画，防止连续被砍时动画冲突
var catchup_tween: Tween 

func _ready() -> void:
	BattleBus.player_hp_changed.connect(_on_player_hp_changed)


func _on_player_hp_changed(current: int, max_hp: int) -> void:
	
	show_hp.text = "%d" % [current]
	print("PlayerUI：成功同步血量数值显示，当前血量为%d" %current)
	
	current_hp_bar.max_value = max_hp
	different_hp_bar.max_value = max_hp
	
	current_hp_bar.value = current
	
	if catchup_tween and catchup_tween.is_valid():
		catchup_tween.kill()
		
	catchup_tween = create_tween()
	
	catchup_tween.tween_property(different_hp_bar, "value", current, 0.4)\
		.set_delay(0.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
