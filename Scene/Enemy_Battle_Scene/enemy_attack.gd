extends State

# 战斗节奏参数 (未来你可以把这些参数放到 AIBrain 里，让不同机制词条修改它们)
var windup_time: float = 0.6      # 1. 前摇时长：玩家看到起手势
var telegraph_time: float = 0.4   # 2. 提示时长：高危警告，弹反的黄金期开始
var recovery_time: float = 0.8    # 4. 后摇时长：敌人大喘气，玩家的绝对安全输出期

func enter(msg: Dictionary = {}) -> void:
	# 开启异步协程，按顺序执行四个阶段
	_execute_attack_flow()

func _execute_attack_flow() -> void:
	# ================= 阶段 1：前摇 (Wind-up) =================
	print("EnemyAttack [1/4]：前摇开始")
	# [画面表现]：播放敌人抬手、深呼吸、或武器向后拉伸的动画
	
	await get_tree().create_timer(windup_time).timeout
	
	
	# ================= 阶段 2：攻击提示 (Telegraph) =================
	print("EnemyAttack [2/4]：攻击提示！(玩家弹反判定点即将到来)")
	# [画面表现]：头顶闪烁红光、弹出类只狼的“危”字、播放“叮”的蓄力音效、武器附魔高亮等强视觉反馈
	
	await get_tree().create_timer(telegraph_time).timeout
	
	
	# ================= 阶段 3：攻击打出 (Attack) =================
	print("EnemyAttack [3/4]：伤害结算！")
	# [画面表现]：播放武器挥下的瞬间动作、伴随破空音效
	# [画面表现]：(可选) 如果打中玩家，触发极短暂的屏幕震动 (Camera Shake) 或 顿帧 (Hitstop)
	
	# 核心逻辑：算出伤害并打包，扔给 EventBus 水管
	var calculator = host.get_node("Data/Calculator")
	var final_dmg = calculator.calculate_outgoing_damage()
	var payload = {
		"damage": final_dmg,
		"source": host,
		"type": "physical"
	}
	EventBus.enemy_dealt_damage.emit(payload)
	
	
	# ================= 阶段 4：攻击后摇 (Recovery) =================
	print("EnemyAttack [4/4]：进入后摇硬直")
	# [画面表现]：播放敌人大喘气、因惯性身体前倾、缓慢收起武器的动画
	# [画面表现]：(可选) 改变敌人材质颜色变暗，或者UI提示“破绽”，暗示当前是玩家出牌输出的安逸期
	
	await get_tree().create_timer(recovery_time).timeout
	
	
	# 流程结束，收尾并切回发呆状态
	print("EnemyAttack：攻击流程结束，返回 Idle")
	get_parent().transition_to("Idle")
