# player_parry
#
# 进入阶段就记为格挡开始
# 提供更改格挡手感的方法与查询窗口

extends State

@onready var visuals = $"../../Visuals/PlayerVisuals"

# 记录当前格挡阶段
var current_parry_quality: String = "startup"

# 进入后设置格挡阶段为开始
func enter(msg: Dictionary = {}) -> void:
	
	print("玩家进入状态：Parry")
	current_parry_quality = "startup" # 默认初始状态
	
	# 连接动画帧发出的信号
	if not visuals.parry_window_changed.is_connected(set_parry_quality):
		visuals.parry_window_changed.connect(set_parry_quality)
	
	visuals.play_parry()
	await visuals.anim_player.animation_finished
	
	# 动画结束，如果不强制打断的话，切回待机
	if get_parent().current_state == self:
		get_parent().transition_to("Idle")
	
func exit() -> void:
	# 退出状态时断开连接，防止发生Bug
	if visuals.parry_window_changed.is_connected(set_parry_quality):
		visuals.parry_window_changed.disconnect(set_parry_quality)
		
# ==========================================
# 开放调用的专属方法
# ==========================================

# 跟进格挡状态
func set_parry_quality(quality: String) -> void:
	current_parry_quality = quality
	print("玩家格挡：动画帧到达！当前格挡判定切换为：", quality)

# 提供一个检查当前格挡阶段的方法
func get_parry_quality() -> String:
	return current_parry_quality
