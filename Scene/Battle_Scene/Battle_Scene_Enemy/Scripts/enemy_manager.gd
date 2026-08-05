# enemy_manager
#
# 敌人初始化
# 玩家伤害处理
# 敌人时间轴行动结算入口

extends Node
class_name EnemyManager

@export var enemy_tier: int = 1
@export var mechanic_count: int = 2

@onready var combat_data: EnemyCombatData = %CombatData
@onready var calculator: EnemyCalculator = %Calculator
@onready var state_machine: EnemyStateMachine = %StateMachine


func _ready() -> void:
	print("====== 敌人装配开始 ======")
	print("当前敌人阶级: Tier ", enemy_tier)


# 玩家伤害处理。
func take_damage(payload: Dictionary) -> void:
	var incoming_damage := int(
		payload.get(
			"damage",
			0
		)
	)

	var real_damage := calculator.calculate_incoming_damage(
		incoming_damage
	)

	combat_data.get_hit(
		real_damage,
		"player_attack"
	)


# 行动轴中的敌人行动到期时调用。
func resolve_timeline_action(action: TimelineAction) -> void:
	if action == null:
		return

	var payload := action.payload

	var action_data_variant = payload.get(
		"action_data",
		{}
	)

	if typeof(action_data_variant) != TYPE_DICTIONARY:
		push_error("EnemyManager：敌人行动数据不是 Dictionary。")
		return

	var action_data: Dictionary = action_data_variant

	if action_data.is_empty():
		push_error("EnemyManager：敌人行动数据为空。")
		return

	var category := str(
		payload.get(
			"category",
			action_data.get(
				"category",
				""
			)
		)
	)

	match category:
		"attack":
			state_machine.transition_to(
				"Attack",
				{
					"action_data": action_data
				}
			)

		"defence":
			_resolve_defence_action(action_data)

		"skill":
			_resolve_skill_action(action_data)

		_:
			push_warning(
				"EnemyManager：未知敌人行动类别：%s"
				% category
			)


# 当前测试数据中的闪避和防御先记录到 Buff 数据。
# 具体闪避判定和格挡伤害可以在后续继续实现。
func _resolve_defence_action(
	action_data: Dictionary
) -> void:
	var effect_type := str(
		action_data.get(
			"effect_type",
			""
		)
	)

	var duration := float(
		action_data.get(
			"duration",
			0.0
		)
	)

	match effect_type:
		"dodge_buff":
			var dodge_bonus := float(
				action_data.get(
					"dodge_bonus",
					0.0
				)
			)

			combat_data.apply_buff(
				"dodge_bonus",
				dodge_bonus,
				duration
			)

		"block_next_attack":
			var charges := float(
				action_data.get(
					"charges",
					1
				)
			)

			combat_data.apply_buff(
				"block_next_attack",
				charges,
				duration
			)

		_:
			print(
				"EnemyManager：防御行动已结算，但尚无具体效果：",
				effect_type
			)


# 当前测试数据中的技能先写入敌人 Buff 数据。
func _resolve_skill_action(
	action_data: Dictionary
) -> void:
	var effect_type := str(
		action_data.get(
			"effect_type",
			""
		)
	)

	match effect_type:
		"rebirth_charge":
			var charge_amount := float(
				action_data.get(
					"charge_amount",
					1
				)
			)

			combat_data.apply_buff(
				"rebirth_charge",
				charge_amount,
				999999.0
			)

		_:
			print(
				"EnemyManager：技能行动已结算，但尚无具体效果：",
				effect_type
			)


# ActionTimelineManager 在结算行动前会检查这个方法。
func can_resolve_timeline_action(
	_action: TimelineAction
) -> bool:
	if combat_data == null:
		return false

	return combat_data.enemy_current_hp > 0
