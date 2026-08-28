class_name CombatProcessor
extends Node

# 需要动画效果
signal visual_effect_generated(effect_data: Dictionary)

# 纯逻辑执行方法，瞬间完成
func execute_logic(action: CombatAction):
	# 构造将要发给外部系统的表现参数
	var visual_params = {
		"is_player": action.is_player,
		"action_name": action.action_name,
		"type": action.effect_data.get("type", "default")
	}

	match action.effect_data.get("type", ""):
		"attack":
			visual_params["damage"] = action.effect_data.get("damage", 0)
	# 将表现需求上报给Manager
	visual_effect_generated.emit(visual_params)
