# player_combat_data
# 
# 体力能量恢复和消耗
# 玩家受伤与格挡判定


extends Node
class_name PlayerCombatData

#绑定同级节点
@onready var calculator:PlayerCalculator = $"../Calculator"
@onready var inventory:PlayerInventory = $"../Inventory"
@onready var visuals = $"../../Visuals/PlayerVisuals"


# ==========================================
# 参数部分
# ==========================================
# —————— 定义信号 ——————
signal hp_changed(current_hp, max_hp) # 生命值变化后广播
signal stamina_changed(current_stamina, max_stamina) # 体力变化后广播
signal mana_changed(current_mana, max_mana) # 能量变化后广播
signal not_enough_stamina() # 体力不足
signal not_enough_mana() # 能量不足


# —————— 基础面板 ——————
@export var current_hp: float # 实时生命
@export var max_hp: float # 最大生命值

@export var current_stamina: int # 实时体力
@export var max_stamina: int # 最大体力

@export var current_mana: int # 实时能量
@export var max_mana: int # 最大能量

@export var current_defence: float # 实时防御力
@export var current_shield: float # 实时护盾值

@export var current_stamina_recover_speed: float # 体力恢复速度
@export var current_mana_recover_speed: float # 能量恢复速度

# —————— 功能实现参数 ——————
var _stamina_recovery_timer: float = 0.0 # 体力恢复累计器
var _mana_recovery_timer: float = 0.0 # 能量恢复累计器


# ==========================================
# 初始化：战斗开始时同步初始数据给 UI
# ==========================================
func _ready() -> void:
	# 使用 call_deferred 延迟到当前帧结束时执行
	# 这样可以保证 UI 节点的 _ready 已经执行，信号线已经接好
	call_deferred("_sync_initial_stats")

func _sync_initial_stats() -> void:
	print("玩家战斗数据：向 UI 推送初始面板数据...")
	BattleBus.player_hp_changed.emit(current_hp, max_hp)
	BattleBus.player_stamina_changed.emit(current_stamina, max_stamina)
	BattleBus.player_mana_changed.emit(current_mana, max_mana)

# ==========================================
# 体力、能量恢复（被动）
# ==========================================

# 1.体力恢复
func stamina_recovery(delta:float)->void:
	# 体力未满就开始恢复体力
	if current_stamina < max_stamina:
		_stamina_recovery_timer += delta
		
		# 跑完所需时间，体力就加一
		if _stamina_recovery_timer >= current_stamina_recover_speed:
			current_stamina += 1
			
			# 清空计时器，重新开始下一轮1点体力的计算
			_stamina_recovery_timer -= current_stamina_recover_speed 
			
			# 发送全局信号，通知 UI 刷新
			BattleBus.player_stamina_changed.emit(current_stamina, max_stamina) 
			
			print("玩家战斗数据：体力恢复 + 1，当前体力：%d" % current_stamina)

# 2. 能量恢复
func mana_recovery(delta:float):
	# 能量未满就开始恢复体力
	if current_mana  < max_mana:
		_mana_recovery_timer += delta
		
		# 跑完所需时间，能量就加一
		if _mana_recovery_timer >= current_mana_recover_speed:
			current_mana += 1
			
			# 清空计时器，重新开始下一轮1点能量的计算
			_mana_recovery_timer -= current_mana_recover_speed 
			
			# 发送全局信号，通知 UI 刷新】
			BattleBus.player_mana_changed.emit(current_mana, max_mana) 
			
			print("玩家战斗数据：能量恢复 + 1，当前能量：%d" % current_mana)


# ==========================================
# 体力、能量扣除方法（主动）
# ==========================================
# 1. 体力扣除
func consume_stamina(cost: int) -> bool:
	if current_stamina >= cost:
		current_stamina -= cost
		
		# 消耗体力后，打断当前的充能进度，从零开始重新算
		_stamina_recovery_timer = 0.0 
		# 体力变化后发送信号（让UI变动、敌人AI检测）
		stamina_changed.emit(current_stamina, max_stamina) # 玩家系统内信号
		BattleBus.player_stamina_changed.emit(current_stamina,max_stamina) # 全局信号
		print("玩家战斗数据：消耗 %d 点体力" % cost)
		return true
	else:
		print("玩家战斗数据：体力不足！")
		return false
# 2. 能量扣除
func consume_mana(cost: int) -> bool:
	if current_mana >= cost:
		current_mana -= cost
		
		# 消耗能量后，打断当前的充能进度，从零开始重新算
		_mana_recovery_timer = 0.0 
		# 能量变化后发送信号（让UI变动、敌人AI检测）
		mana_changed.emit(current_mana, max_mana)
		print("玩家战斗数据：消耗 %d 点能量" % cost)
		BattleBus.player_stamina_changed.emit(current_stamina,max_stamina)
		return true
	else:
		print("玩家战斗数据：能量不足！")
		return false



# ==========================================
# 玩家受伤与格挡判定
# ==========================================
# 1. 受伤方法
func get_hit(incoming_damage: int, hit_context: String = "combat"):
	var state_machine = $"../../StateMachine" # 注意这里的相对路径，确保能找到状态机
	var final_damage = incoming_damage
	
	# 判定玩家是否处于格挡状态
	if state_machine and state_machine.current_state and state_machine.current_state.name == "Parry":
		# 在格挡：启动格挡状态内的格挡方法
		var quality = state_machine.current_state.get_parry_quality()
		
		# ----------------------------------------
		# 1. 完美格挡 (Perfect)
		# ----------------------------------------
		if quality == "perfect":
			final_damage = 0 # 抵御全部伤害
			print("✨ 完美弹反！不消耗体力，完全抵御伤害！")
			
			_trigger_perfect_parry_slowmo() # 触发超强正反馈慢动作！
			
			if visuals:visuals.play_parry_sound()
			# (进阶) 你可以在这里发射一个信号，通知敌人扣除架势条，或让敌人陷入眩晕状态
			
		# ----------------------------------------
		# 2. 普通格挡 (Normal)
		# ----------------------------------------
		elif quality == "normal":
			var stamina_cost = 1 
			print("🛡️ 普通格挡判定！尝试消耗 %d 点体力..." % stamina_cost)
			
			if consume_stamina(stamina_cost): # 正常消耗体力
				final_damage = 0 # 体力足够，抵御全部伤害
				print("防御成功！未受伤害。")
				
				if visuals:visuals.play_parry_sound()
			else:
				# 体力不足，破防！受到全额伤害
				print("❌ 破防！体力不足，受到全额伤害！")
				
		# ----------------------------------------
		# 3. 无效阶段 (startup / recovery)
		# ----------------------------------------
		else:
			print("💥 格挡时机不对(前摇或后摇中)！直接受到全额伤害！")
			# final_damage 保持不变，下面会扣血
			
	# ==========================================
	# 最终伤害结算扣血
	# ==========================================
	if final_damage > 0:
		current_hp -= final_damage
		current_hp = clampf(current_hp, 0.0, max_hp) # 防止血量变成负数
		
		# 发送UI更新信号
		hp_changed.emit(current_hp, max_hp) 
		
		BattleBus.player_hp_changed.emit(current_hp, max_hp) 
		
		visuals.play_get_hit_sound()
		print("🩸 受到 %d 点伤害，剩余血量：%d" % [final_damage, current_hp])
		
		if current_hp <= 0:
			print("💀 玩家阵亡...")
			BattleBus.player_died.emit(hit_context)


# ==========================================
# 视觉表现：完美格挡全局慢动作 (Hitstop)
# ==========================================
func _trigger_perfect_parry_slowmo() -> void:
	# 1. 瞬间将游戏全局速度降至 10% (极具冲击力的停顿感)
	Engine.time_scale = 0.01 
	
	# 2. 创建一个补间动画，让时间平滑恢复
	var tween = create_tween()
	
	# 【极其关键的一行】：必须让这个 Tween 忽略全局 time_scale 的影响！
	# 否则游戏变慢了，这个恢复时间的动画也会变慢，导致玩家卡在慢动作里出不来
	tween.set_ignore_time_scale(true) 
	
	# 3. 在 0.5 秒(现实时间)内，把 Engine.time_scale 属性从 0.1 缓出恢复到 1.0
	tween.tween_property(Engine, "time_scale", 1.0, 2)\
		.set_trans(Tween.TRANS_QUART)\
		.set_ease(Tween.EASE_OUT)
