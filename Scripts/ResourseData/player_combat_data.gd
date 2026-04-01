# 定义：玩家核心数据资源
# 作用：
# 存储数据



extends Node

class_name PlayerCombatData # 注册为全局类，方便在其他地方调用

# —————— 定义信号 ——————
signal hp_changed(current_hp, max_hp) # 生命值变化后广播
signal stanima_changed(current_stanima, max_stanima) # 体力变化后广播
signal mana_changed(current_stanima, max_stanima) # 能量变化后广播

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


# —————— 资源恢复部分 ——————
# 体力恢复
func stanima_recovery(delta:float)->void:
	# 体力未满就开始恢复体力
	if current_stanima < max_stanima:
		_stanima_recovery_timer += delta
		
		# 跑完所需时间，体力就加一
		if _stanima_recovery_timer >= current_stanima_recover_speed:
			current_stanima += 1
			print("战斗数据：体力恢复 + 1")
# 能量恢复
func mana_recovery(delta:float):
	# 能量未满就开始恢复体力
	if current_mana  < max_mana:
		_mana_recovery_timer += delta
		
		# 跑完所需时间，能量就加一
		if _mana_recovery_timer >= current_mana_recover_speed:
			current_mana += 1
			print("战斗数据：能量恢复 + 1")

# —————— 资源扣除部分 ——————
# 体力扣除
func consume_stanima(cost: int) -> bool:
	if current_stanima >= cost:
		current_stanima -= cost
		
		# 【动作游戏细节】消耗体力后，打断当前的充能进度，从零开始重新算
		_stanima_recovery_timer = 0.0 
		
		stanima_changed.emit(current_stanima, max_stanima)
		print("战斗数据：消耗 %d 点体力" % cost)
		return true
	else:
		print("战斗数据：体力不足！")
		return false
# 能量扣除
func consume_mana(cost: int) -> bool:
	if current_mana >= cost:
		current_mana -= cost
		
		# 【动作游戏细节】消耗体力后，打断当前的充能进度，从零开始重新算
		_stanima_recovery_timer = 0.0 
		
		mana_changed.emit(current_mana, max_mana)
		print("战斗数据：消耗 %d 点能量" % cost)
		return true
	else:
		print("体力不足！")
		return false
