# enemy_attack
#
# 战斗体验数值
# 攻击流程

extends State

@onready var enemy_visual = $"../../Visuals/EnemyVisuals"

# ==========================================
# 战斗体验数值，供机制更改
# ==========================================
var windup_time: float = 0.6      # 1. 前摇时长：玩家看到起手势
var telegraph_time: float = 0.4   # 2. 提示时长：高危警告，弹反的黄金期开始
var recovery_time: float = 0.8    # 4. 后摇时长：敌人大喘气，玩家的绝对安全输出期

func enter(msg: Dictionary = {}) -> void:
	print("敌人进入状态：Attack")
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
	
# 发出伤害
