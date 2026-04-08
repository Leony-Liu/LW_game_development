extends State

var card_data: Dictionary

func enter(msg: Dictionary = {}) -> void:
	if msg.has("card"):
		card_data = msg["card"]
	
	print("Attack-玩家状态：开始播放攻击状态")
	host.get_node("Visuals/AnimationPlayer").play("player_attack")
	
	# 【临时逻辑】：因为现在没有动画事件，我们用代码延迟 0.5 秒，模拟“刀砍到敌人身上”的那一帧
	await get_tree().create_timer(0.5).timeout
	
	# 执行伤害结算
	_execute_damage()
	
	# 打完之后，自动切回待机状态
	get_parent().transition_to("Idle")


func _execute_damage() -> void:
	# 1. 从卡牌数据里拿出“基础伤害”（这里加了个容错，如果没有 base_damage 字段默认给 10）
	var base_dmg = card_data.get("base_damage", 10) 
	
	# 2. 呼叫计算器，算出加上装备增益后的最终真实伤害
	var calculator = host.get_node("Data/Calculator")
	var final_dmg = calculator.calculate_outgoing_damage(base_dmg)
	
	# 3. 把伤害数据打包成一个字典（Payload），方便以后塞入更多信息
	var payload = {
		"damage": final_dmg,       # 最终伤害数值
		"source": host,            # 是谁打出的伤害
		"type": "physical"         # 伤害类型（物理/魔法/真实）
	}
	
	print("Attack-玩家状态：计算完毕，发出伤害数据 -> ", payload)
	
	# 4. 把伤害包丢进信号管道
	EventBus.player_dealt_damage.emit(payload)
