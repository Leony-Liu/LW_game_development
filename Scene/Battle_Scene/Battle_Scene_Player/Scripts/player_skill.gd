# player_skill.gd

extends State

var card_data: Dictionary

@export var effect_mgr: Node


func enter(msg: Dictionary = {}) -> void:
	print("玩家进入状态：Skill")

	card_data = {}

	if msg.has("card"):
		card_data = msg["card"]

	var effect_string := str(
		card_data.get(
			"effects",
			""
		)
	)

	if (
		effect_string != ""
		and effect_string != "0"
	):
		if effect_mgr:
			effect_mgr.execute_effects(
				effect_string,
				host,
				host
			)

			print(
				"技能状态：已触发技能效果 -> ",
				effect_string
			)
		else:
			push_error(
				"PlayerSkill："
				+ "找不到 EffectManager 节点。"
			)

	if get_parent().current_state == self:
		get_parent().transition_to("Idle")

	# 当前技能没有单独动画，因此效果结束后立即完成。
	if host.has_method(
		"finish_timeline_action"
	):
		host.finish_timeline_action()
