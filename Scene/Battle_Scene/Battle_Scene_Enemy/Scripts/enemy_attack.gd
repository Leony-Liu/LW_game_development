# enemy_attack
#
# 接收时间轴中的敌人行动数据
# 播放攻击动画并发送伤害

extends State

@onready var enemy_visual = $"../../Visuals/enemy_3dvisuals"
@onready var enemy_calculator = $"../../Data/Calculator"

var current_action_data: Dictionary = {}


func enter(msg: Dictionary = {}) -> void:
	print("敌人进入状态：Attack")

	current_action_data.clear()

	var action_data_variant = msg.get(
		"action_data",
		{}
	)

	if typeof(action_data_variant) == TYPE_DICTIONARY:
		current_action_data = (
			action_data_variant as Dictionary
		).duplicate(true)

	if not enemy_visual.enemy_hit_frame_reached.is_connected(
		_deal_damage
	):
		enemy_visual.enemy_hit_frame_reached.connect(
			_deal_damage
		)

	_execute_attack()


func exit() -> void:
	if enemy_visual.enemy_hit_frame_reached.is_connected(
		_deal_damage
	):
		enemy_visual.enemy_hit_frame_reached.disconnect(
			_deal_damage
		)

	current_action_data.clear()


# 动画命中帧到达时发送伤害。
func _deal_damage() -> void:
	var damage = enemy_calculator.calculate_outgoing_damage()

	var effect_type := str(
		current_action_data.get(
			"effect_type",
			"damage"
		)
	)

	match effect_type:
		"damage":
			damage = int(
				current_action_data.get(
					"damage",
					damage
				)
			)

		"multi_damage":
			var hit_count := maxi(
				int(
					current_action_data.get(
						"hit_count",
						1
					)
				),
				1
			)

			var damage_per_hit := int(
				current_action_data.get(
					"damage_per_hit",
					damage
				)
			)

			# 当前先按一次总伤害结算。
			# 后续制作连续命中动画时再拆分为多次伤害信号。
			damage = damage_per_hit * hit_count

		_:
			damage = int(
				current_action_data.get(
					"damage",
					damage
				)
			)

	var payload := {
		"damage": damage,
		"source": host,
		"type": str(
			current_action_data.get(
				"damage_type",
				"physical"
			)
		)
	}

	BattleBus.enemy_dealt_damage.emit(payload)

	print(
		"敌人攻击：对玩家发出伤害 -> %d"
		% damage
	)


func _execute_attack() -> void:
	if enemy_visual.has_method("play_attack"):
		enemy_visual.play_attack()

	await enemy_visual.anim_player.animation_finished

	if get_parent().current_state == self:
		get_parent().transition_to("Idle")
