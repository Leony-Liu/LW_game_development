extends Node

@onready var combat_data: PlayerCombatData = $Data/CombatData
@onready var state_machine: StateMachine = %StateMachine


# 玩家卡牌对应的动作、动画已经全部播放完毕。
signal timeline_action_finished(
	action: TimelineAction
)

# 当前正在播放表现的时间轴行动。
var _resolving_timeline_action: TimelineAction = null

# 判断玩家当前是否允许提交这张卡牌。
# 此处只检查状态和资源，不扣除资源，也不执行卡牌。
func can_commit_card(card_data: Dictionary) -> bool:
	if state_machine == null:
		push_error("PlayerManager：找不到 StateMachine。")
		return false

	if state_machine.current_state == null:
		push_warning("PlayerManager：玩家状态机尚未初始化。")
		return false

	if state_machine.current_state.name != "Idle":
		print(
			"PlayerManager：玩家当前处于 %s，不能出牌。"
			% state_machine.current_state.name
		)
		return false

	var category := str(card_data.get("categories", ""))

	match category:
		"attack":
			var stamina_cost := maxi(
				int(card_data.get("stamina_cost", 0)),
				0
			)

			if combat_data.current_stamina < stamina_cost:
				print("PlayerManager：体力不足，不能提交攻击牌。")
				return false

			return true

		"skill":
			var mana_cost := maxi(
				int(card_data.get("mana_cost", 0)),
				0
			)

			if combat_data.current_mana < mana_cost:
				print("PlayerManager：能量不足，不能提交技能牌。")
				return false

			return true

		_:
			push_warning(
				"PlayerManager：未知卡牌类别：%s"
				% category
			)
			return false


# 卡牌确认可以提交后，在这里统一支付资源。
# 资源只在提交时扣除一次，行动结算时不能再次扣除。
func pay_card_cost(card_data: Dictionary) -> bool:
	var category := str(card_data.get("categories", ""))

	match category:
		"attack":
			var stamina_cost := maxi(
				int(card_data.get("stamina_cost", 0)),
				0
			)

			if combat_data.consume_stamina(stamina_cost):
				return true

			combat_data.not_enough_stamina.emit()
			return false

		"skill":
			var mana_cost := maxi(
				int(card_data.get("mana_cost", 0)),
				0
			)

			if combat_data.consume_mana(mana_cost):
				return true

			combat_data.not_enough_mana.emit()
			return false

		_:
			return false


# 行动轴准备结算玩家行动时调用。
# 到这里才真正进入 Attack 或 Skill 状态。
func resolve_timeline_action(
	action: TimelineAction
) -> void:
	if action == null:
		return

	_resolving_timeline_action = action

	var card_data_variant = action.payload.get(
		"action_data",
		{}
	)

	if typeof(card_data_variant) != TYPE_DICTIONARY:
		push_error(
			"PlayerManager："
			+ "行动中的卡牌数据不是 Dictionary。"
		)

		finish_timeline_action()
		return

	var card_data: Dictionary = card_data_variant

	if card_data.is_empty():
		push_error(
			"PlayerManager：行动中没有卡牌数据。"
		)

		finish_timeline_action()
		return

	var category := str(
		card_data.get(
			"categories",
			""
		)
	)

	match category:
		"attack":
			state_machine.transition_to(
				"Attack",
				{
					"card": card_data
				}
			)

		"skill":
			state_machine.transition_to(
				"Skill",
				{
					"card": card_data
				}
			)

		_:
			push_warning(
				"PlayerManager："
				+ "无法结算未知卡牌类别：%s"
				% category
			)

			finish_timeline_action()

# Attack 或 Skill 状态在表现结束后调用。
func finish_timeline_action() -> void:
	if _resolving_timeline_action == null:
		return

	var finished_action := _resolving_timeline_action
	_resolving_timeline_action = null

	timeline_action_finished.emit(
		finished_action
	)
	
# ActionTimelineManager 在正式结算前会自动检查这个方法。
func can_resolve_timeline_action(
	_action: TimelineAction
) -> bool:
	if combat_data == null:
		return false

	return combat_data.current_hp > 0
