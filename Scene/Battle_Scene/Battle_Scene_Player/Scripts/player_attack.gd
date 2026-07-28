# player_attack
#
# 接收数据并输出
# 核心拓展：引入攻击牌自身的 Effect/Buff 解析器

extends State

@onready var visuals = $"../../PlayerVisuals/Visuals/player_3Dvisuals"

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

# 2. 打包伤害与全新效果结算流程
func _execute_damage() -> void:
	var base_dmg = card_data.get("damage", 10) 
	var calculator = host.get_node("Data/Calculator")
	var final_dmg = calculator.calculate_outgoing_damage(base_dmg)
	
	var payload = {
		"damage": final_dmg,       
		"source": host,      
		"type": "physical"         
	}
	print("Attack-玩家状态：计算完毕，发出伤害数据 -> ", payload)
	
	# 1. 伤害发出去给敌人
	BattleBus.player_dealt_damage.emit(payload)
	
	# 2. 【全新架构介入】：通知战斗数据，执行所有的“攻击后消耗”逻辑！
	var combat_data = host.get_node("Data/CombatData")
	if combat_data.has_method("consume_buffs_by_trigger"):
		combat_data.consume_buffs_by_trigger("on_attack")

# ====================================================================
	# 🌟 【核心新增】：像技能牌一样，解析并执行当前攻击牌自身携带的 effects
# ====================================================================
	# 修复点：在外层加上 str()，强制把取出来的数据变成字符串
	var effect_string = str(card_data.get("effects", "")) 
	
	if effect_string != "" and effect_string != "0":
		# 根据你项目节点树的定位，这里向上寻找与 StateMachine 同级的 EffectManager
		var effect_mgr = host.get_node_or_null("../EffectManager")
		# ... 后续代码保持不变 ...
