# player_parry.gd
extends State

var parry_start_time: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	# 记录按下格挡键那一瞬间的时间
	parry_start_time = Time.get_ticks_msec() / 1000.0 
	print("玩家进入防御姿态！")
	#host.get_node("Visuals/AnimationPlayer").play("player_block") # 播放举盾/架刀动画


func update(delta: float) -> void:
	# 如果玩家松开格挡键，切回 Idle
	if Input.is_action_just_released("block_key"):
		get_parent().transition_to("Idle")


# 提供给外部（比如计算器或CombatData）查询的接口
func get_parry_quality() -> String:
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_in_parry = current_time - parry_start_time
	
	# 假设按下格挡的前 0.2 秒是完美弹反窗口
	if time_in_parry <= 0.2:
		return "perfect"
	else:
		return "normal"
