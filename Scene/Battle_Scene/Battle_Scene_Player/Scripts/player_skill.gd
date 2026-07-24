# player_skill.gd
extends State

var card_data: Dictionary

func enter(msg: Dictionary = {}) -> void:
	print("玩家进入状态：Skill")
	if msg.has("card"):
		card_data = msg["card"]
	
	# 1. 提取并执行技能牌的效果
	var effect_string = card_data.get("effects", "")
	if effect_string != "" and effect_string != "0":
		# 【修复Bug】：路径从 "../../EffectManager" 改为 "../EffectManager"
		var effect_mgr = host.get_node_or_null("../EffectManager")
		if effect_mgr:
			# 技能牌通常作用于自身，所以 source 和 target 都填 host
			effect_mgr.execute_effects(effect_string, host, host)
			print("技能状态：已触发技能效果 -> ", effect_string)
		else:
			push_error("致命错误：技能状态找不到 EffectManager 节点！")
			
	# 2. 效果执行完毕，立刻切回待机状态
	if get_parent().current_state == self:
		get_parent().transition_to("Idle")
