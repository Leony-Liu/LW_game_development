# enemy_visuals_manager
#
#

extends Node2D

@onready var anim = $AnimationPlayer 

# ==========================================
# 体验变量
# ==========================================
var current_telegraph_time: float  # 提示阶段时长
var current_wait_time: float       # 等待阶段时长

# ==========================================
# 前摇结束后调用
# ==========================================
func pause_for_telegraph():
	# 1. 瞬间定格动画（前摇结束，保持高举武器）
	anim.pause()
	print("提示等待代码正常生效")
	# ----------------------------------------
	# 【阶段 2：提示】
	# ----------------------------------------
	
	# TODO 这里可以插入提示效果
	
	
	# 强制等待提示阶段彻底完成
	if current_telegraph_time > 0:
		await get_tree().create_timer(current_telegraph_time).timeout
		
	# ----------------------------------------
	# 【阶段 3：等待】
	# ----------------------------------------
	
	# 等待程序设定的额外停顿时间
	if current_wait_time > 0:
		await get_tree().create_timer(current_wait_time).timeout
	
	# ----------------------------------------
	# 【阶段 4：攻击】
	# ----------------------------------------
	
	# 时间到，恢复动画播放
	anim.play()
