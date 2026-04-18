# player_attack
#
# 接收数据并输出


extends State

@onready var visuals = $"../../Visuals/PlayerVisuals"

var card_data: Dictionary

# ==========================================
# 接收数据并输出
# ==========================================
# 1. 接收后攻击流程启动
func enter(msg: Dictionary = {}) -> void:
	print("玩家进入状态：Attack")
	if msg.has("card"):
		card_data = msg["card"]
	
	if visuals and visuals.has_method("play_attack"):
		visuals.play_attack()
	
	# 通过信号连接攻击方法
	if not visuals.hit_frame_reached.is_connected(_execute_damage):
		visuals.hit_frame_reached.connect(_execute_damage)
	
	# 【核心】等待攻击动画彻底播放完毕
	if visuals:
		await visuals.anim_player.animation_finished
	
	# 【安全判定】确保等待期间状态没有被强制改变（比如突然被敌人打出硬直死亡）
	if get_parent().current_state == self:
		get_parent().transition_to("Idle") # 动画播完了，才切回待机状态

# 2. 打包伤害
func _execute_damage() -> void:
	# 1. 从卡牌数据里拿出“基础伤害”（这里加了个容错，如果没有 base_damage 字段默认给 10）
	var base_dmg = card_data.get("damage", 10) 
	
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
