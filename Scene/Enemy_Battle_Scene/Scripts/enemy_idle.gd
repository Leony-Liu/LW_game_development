# enemy_idle
#
# TODO 模拟ai，一定时间后切换到攻击模式

extends State

var wait_timer: float = 0.0
var target_wait_time: float = 2.0


func enter(msg: Dictionary = {}) -> void:
	print("敌人进入状态：Idle")
	wait_timer = 0.0
	
	# TODO 暂定行动间隔生成
	var ai_brain = host.get_node_or_null("EnemyAIBrain")
	if ai_brain:
		# 随机生成行动间隔，让敌人的行动具有不可预测性
		target_wait_time = randf_range(ai_brain.min_idle_time, ai_brain.max_idle_time)
	else:
		target_wait_time = 2.0
		
	print("EnemyIdle：开始发呆，准备在 %.1f 秒后行动" % target_wait_time)
	
	# ==========================================
	# [画面表现]：在这里播放敌人的 默认呼吸 / 待机 动画
	# 例如：host.get_node("Visuals/AnimationPlayer").play("idle")
	# ==========================================

func update(delta: float) -> void:
	wait_timer += delta
	# 时间一到，立马切到攻击状态
	if wait_timer >= target_wait_time:
		get_parent().transition_to("Attack")
