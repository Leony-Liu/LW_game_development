# player_parry
#
# 进入阶段就记为格挡开始
# 提供更改格挡手感的方法与查询窗口

extends State

# 记录当前格挡阶段
var current_parry_quality: String = "startup"

# 进入后设置格挡阶段为开始
func enter(msg: Dictionary = {}) -> void:
	print("玩家进入状态：Parry")
	current_parry_quality = "startup"
	
	# host.get_node("Visuals/AnimationPlayer").play("player_parry_action") 


# ==========================================
# 开放调用的专属方法
# ==========================================

# 跟进格挡状态
func set_parry_quality(quality: String) -> void:
	current_parry_quality = quality
	print("玩家格挡：动画帧到达！当前格挡判定切换为：", quality)

# 结束格挡
func finish_parry() -> void:
	print("玩家格挡：弹反动作结束，收招回待机。")
	get_parent().transition_to("Idle")

# 
func get_parry_quality() -> String:
	return current_parry_quality
