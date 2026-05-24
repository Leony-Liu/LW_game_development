# enemy_combat_data
#
# 基础数据
# 提供修改数据的方法

extends Node
class_name EnemyCombatData

# ==========================================
# 基础数值
# ==========================================
@export var enemy_max_hp: int = 100 # 最大生命
@export var enemy_current_hp: int = 100 # 当前生命
@export var enemy_damage: int = 10 # 基础攻击

@export var enemy_defense: int = 0 # 基础防御值（固定数值）
@export var enemy_reduction: int = 0 # 基础防御力（百分比）
@export var enemy_poise: int = 100 # 基础韧性值

@export var physical_damage_multiplier: int = 0 # 物理伤害倍率
@export var magical_damage_multiplier: int = 0 # 物理伤害倍率
@export var real_damage_multiplier: int = 0 # 真实伤害倍率

var active_buffs: Dictionary = {}

# ==========================================
# 初始化：战斗开始时同步初始数据给 UI
# ==========================================
func _ready() -> void:
	# 使用 call_deferred 延迟到当前帧结束时执行
	# 这样可以保证 UI 节点的 _ready 已经执行，信号线已经接好
	call_deferred("_sync_initial_stats")

func _sync_initial_stats() -> void:
	print("玩家战斗数据：向 UI 推送初始面板数据...")
	BattleBus.enemy_hp_changed.emit(enemy_current_hp,enemy_max_hp)
	
# ==========================================
# 统一状态池 (Buff/Debuff Manager)
# ==========================================

func apply_buff(buff_id: String, value: float, duration: float) -> void:
	if active_buffs.has(buff_id):
		active_buffs[buff_id]["duration"] = max(active_buffs[buff_id]["duration"], duration)
		active_buffs[buff_id]["value"] += value 
	else:
		active_buffs[buff_id] = {"value": value, "duration": duration}
		
	# 通知 UI
	BattleBus.enemy_buffs_changed.emit(active_buffs)

func get_buff_value(buff_id: String) -> float:
	if active_buffs.has(buff_id):
		return active_buffs[buff_id]["value"]
	return 0.0

func _process(delta: float) -> void:
	if active_buffs.is_empty(): return
	var expired_buffs = []
	for buff_id in active_buffs:
		active_buffs[buff_id]["duration"] -= delta
		if active_buffs[buff_id]["duration"] <= 0:
			expired_buffs.append(buff_id)
			
	if expired_buffs.size() > 0:
		for buff_id in expired_buffs:
			active_buffs.erase(buff_id)
		BattleBus.enemy_buffs_changed.emit(active_buffs)
		
# ==========================================
# 主动移除 Buff 的方法
# ==========================================
func remove_buff(buff_id: String) -> void:
	if active_buffs.has(buff_id):
		active_buffs.erase(buff_id)
		# 核心：每次主动移除 Buff，都必须广播通知 UI 刷新！
		BattleBus.enemy_buffs_changed.emit(active_buffs)
		print("🗑️ 已主动消耗/移除 Buff [%s]！" % buff_id)
		
# ==========================================
# 提供改动方法
# ==========================================

# 1. 敌人受伤
func get_hit(real_damage: int, hit_context: String):
	enemy_current_hp -= real_damage
	print("敌人数据：受到 %d 点真实伤害！剩余血量：%d" % [real_damage, enemy_current_hp])
	
	BattleBus.enemy_hp_changed.emit(enemy_current_hp, enemy_max_hp) # 假设最大血量是 100，如果是变量就填 max_hp
	
	if enemy_current_hp <= 0:
		die()

# 2. 敌人死亡
func die():
	print("敌人数据：被击败")
	BattleBus.enemy_died.emit(owner)
	owner.queue_free()
