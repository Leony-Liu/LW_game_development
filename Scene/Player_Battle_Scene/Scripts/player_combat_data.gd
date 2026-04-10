# player_combat_data
# 
# 体力能量恢复和消耗
# 玩家受伤与格挡判定


extends Node
class_name PlayerCombatData

#绑定同级节点
@onready var calculator:PlayerCalculator = $"../Calculator"
@onready var inventory:PlayerInventory = $"../Inventory"

# ==========================================
# 参数部分
# ==========================================
# —————— 定义信号 ——————
signal hp_changed(current_hp, max_hp) # 生命值变化后广播
signal stanima_changed(current_stanima, max_stanima) # 体力变化后广播
signal mana_changed(current_mana, max_mana) # 能量变化后广播
signal not_enough_stanima() # 体力不足
signal not_enough_mana() # 能量不足


# —————— 基础面板 ——————
@export var current_hp: float # 实时生命
@export var max_hp: float # 最大生命值

@export var current_stanima: int # 实时体力
@export var max_stanima: int # 最大体力

@export var current_mana: int # 实时能量
@export var max_mana: int # 最大能量

@export var current_defence: float # 实时防御力
@export var current_shield: float # 实时护盾值

@export var current_stanima_recover_speed: float # 体力恢复速度
@export var current_mana_recover_speed: float # 能量恢复速度

# —————— 功能实现参数 ——————
var _stanima_recovery_timer: float = 0.0 # 体力恢复累计器
var _mana_recovery_timer: float = 0.0 # 能量恢复累计器


# ==========================================
# 体力、能量恢复（被动）
# ==========================================

# 1.体力恢复
func stanima_recovery(delta:float)->void:
	# 体力未满就开始恢复体力
	if current_stanima < max_stanima:
		_stanima_recovery_timer += delta
		
		# 跑完所需时间，体力就加一
		if _stanima_recovery_timer >= current_stanima_recover_speed:
			current_stanima += 1
			print("玩家战斗数据：体力恢复 + 1")
# 2. 能量恢复
func mana_recovery(delta:float):
	# 能量未满就开始恢复体力
	if current_mana  < max_mana:
		_mana_recovery_timer += delta
		
		# 跑完所需时间，能量就加一
		if _mana_recovery_timer >= current_mana_recover_speed:
			current_mana += 1
			print("玩家战斗数据：能量恢复 + 1")


# ==========================================
# 体力、能量扣除方法（主动）
# ==========================================
# 1. 体力扣除
func consume_stanima(cost: int) -> bool:
	if current_stanima >= cost:
		current_stanima -= cost
		
		# 消耗体力后，打断当前的充能进度，从零开始重新算
		_stanima_recovery_timer = 0.0 
		# 体力变化后发送信号（让UI变动、敌人AI检测）
		stanima_changed.emit(current_stanima, max_stanima)
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
		
		# a. 若方法返回为完美格挡
		if quality == "perfect":
			# 清除所有伤害
			final_damage = 0
			print("玩家战斗数据：完美弹反 (Perfect Parry)！免疫全部 %d 点伤害！" % incoming_damage)
			
			# TODO [画面表现] 预留：顿帧(Hitstop)、屏幕震动、播放清脆的打铁音效
			# 【进阶玩法】：在这里 emit 一个信号，让敌人增加架势条(Poise)
			
		# b. 若方法返回为普通格挡
		elif quality == "normal":
			# 消耗一点体力
			var stamina_cost = 1 
			print("玩家战斗数据：普通格挡！尝试消耗 %d 点体力抵挡攻击..." % stamina_cost)
			
			if consume_stanima(stamina_cost):
				print("玩家战斗数据：体力充足，成功防下该次攻击，不受伤害。")
				final_damage = 0
			else:
				# 兜底报错，以防逻辑出错
				push_error("严重错误：玩家在 Parry 状态下体力不足 1 点！")
				final_damage = incoming_damage
	
	# 最终伤害结算
	if final_damage > 0:
		# 当前生命值减去伤害数值
		current_hp -= final_damage
		# 限制玩家血量在 0 到最大血量之间（整数）
		current_hp = clampi(current_hp, 0, max_hp) 
		# 生命值变化后发送信号（让UI变动、敌人AI检测）
		hp_changed.emit(current_hp, max_hp)
		print("玩家战斗数据：：受到 %d 点真实伤害，剩余血量：%d" % [final_damage, current_hp])
		
		# 玩家死亡判定
		if current_hp <= 0:
			print("玩家战斗数据：玩家阵亡...")
			EventBus.player_died.emit(hit_context)
