# enemy_attack
#
# 战斗体验数值
# 攻击流程

extends State

@onready var enemy_visual = $"../../Visuals/EnemyVisuals"
@onready var enemy_calculator = $"../../Data/Calculator"


func enter(msg: Dictionary = {}) -> void:
	print("敌人进入状态：Attack")
	
	if not enemy_visual.enemy_hit_frame_reached.is_connected(_deal_damage):
		enemy_visual.enemy_hit_frame_reached.connect(_deal_damage)
		
	_execute_attack()

func exit() -> void:
	# 退出时断开连接
	if enemy_visual.enemy_hit_frame_reached.is_connected(_deal_damage):
		enemy_visual.enemy_hit_frame_reached.disconnect(_deal_damage)

# ==========================================
# 攻击流程
# ==========================================

# 发出伤害
func _deal_damage() -> void:
	# 1. 让计算器算出伤害
	var dmg = enemy_calculator.calculate_outgoing_damage()
	# 2. 打包数据
	var payload = {
		"damage": dmg,
		"source": host,
		"type": "physical"
	}
	# 3. 通过总线发给裁判
	BattleBus.enemy_dealt_damage.emit(payload)
	print("敌人攻击：对玩家发出伤害 -> ", dmg)
	
func _execute_attack() -> void:
	enemy_visual.anim.play("attack")
	await enemy_visual.anim.animation_finished
	if get_parent().current_state == self:
		get_parent().transition_to("Idle")
