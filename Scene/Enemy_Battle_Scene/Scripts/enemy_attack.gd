# enemy_attack
#
# 战斗体验数值
# 攻击流程

extends State

@onready var enemy_visual = $"../../Visuals/EnemyVisuals"


func enter(msg: Dictionary = {}) -> void:
	print("敌人进入状态：Attack")
	# 开启异步协程，按顺序执行四个阶段
	_execute_attack()

# ==========================================
# 攻击流程
# ==========================================
func _execute_attack() -> void:
	
	enemy_visual.current_telegraph_time = 1.0  # 提示阶段持续 1 秒
	enemy_visual.current_wait_time = 0.5       # 提示结束后，再停顿 0.5 秒才劈下
	
	enemy_visual.anim.play("attack")
	
	# 动画结束后切回Idle
	await enemy_visual.anim.animation_finished
	get_parent().transition_to("Idle")
