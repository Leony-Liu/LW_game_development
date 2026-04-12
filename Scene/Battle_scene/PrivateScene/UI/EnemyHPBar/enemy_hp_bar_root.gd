


extends Control

@onready var current_hp_bar = $current_hp
@onready var different_hp_bar = $different_hp
@onready var show_hp = $MarginContainer/currentHP


# 声明一个变量来存储动画，防止连续被砍时动画冲突
var catchup_tween: Tween 

func _ready() -> void:
	# 监听总线里的敌人扣血信号
	EventBus.enemy_hp_changed.connect(_on_enemy_hp_changed)


func _on_enemy_hp_changed(current: int, max_hp: int) -> void:
	
	show_hp.text = "%d" % [current]
	print("敌人血条：成功同步血量数值显示，当前血量为%d" %current)
	# 1. 更新最大血量上限（以防不同怪物血量上限不同）
	current_hp_bar.max_value = max_hp
	different_hp_bar.max_value = max_hp
	
	# 2. 【核心表现】：红色的真实血条瞬间扣除！毫不拖泥带水！
	current_hp_bar.value = current
	
	# 3. 处理背后的差值血条动画
	# 如果当前有正在播放的扣血动画（比如玩家攻速很快，连续砍了两刀），先强行停掉旧动画
	if catchup_tween and catchup_tween.is_valid():
		catchup_tween.kill()
		
	# 创建一个新的补间动画
	catchup_tween = create_tween()
	
	
	catchup_tween.tween_property(different_hp_bar, "value", current, 0.4)\
		.set_delay(0.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
