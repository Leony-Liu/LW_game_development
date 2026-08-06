# enemy_idle
#
# 离散时间轴模式下，Idle 不再自行计算攻击间隔。
# 敌人只能由时间轴行动驱动状态切换。

extends State

@onready var enemy_visual = $"../../Visuals/enemy_3dvisuals"


func enter(_msg: Dictionary = {}) -> void:
	print("敌人进入状态：Idle")

	if (
		enemy_visual
		and enemy_visual.has_method("play_idle")
	):
		enemy_visual.play_idle()


func update(_delta: float) -> void:
	# 不再使用现实时间自动进入 Attack。
	# 攻击由 EnemyManager.resolve_timeline_action() 触发。
	pass
