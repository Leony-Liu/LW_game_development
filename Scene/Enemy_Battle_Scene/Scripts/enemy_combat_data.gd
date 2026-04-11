# enemy_combat_data
#
# 基础数据
# 提供修改数据的方法

extends Node
class_name EnemyCombatData

# ==========================================
# 基础数值
# ==========================================
@export var enemy_hp: int = 100 # 基础生命
@export var enemy_damage: int = 10 # 基础攻击

@export var enemy_defense: int = 0 # 基础防御值（固定数值）
@export var enemy_reduction: int = 0 # 基础防御力（百分比）
@export var enemy_poise: int = 100 # 基础韧性值

@export var physical_damage_multiplier: int = 0 # 物理伤害倍率
@export var magical_damage_multiplier: int = 0 # 物理伤害倍率
@export var real_damage_multiplier: int = 0 # 真实伤害倍率

# ==========================================
# 提供改动方法
# ==========================================

# 1. 敌人受伤
func get_hit(real_damage: int, hit_context: String):
	enemy_hp -= real_damage
	print("敌人数据：受到 %d 点真实伤害！剩余血量：%d" % [real_damage, enemy_hp])
	
	if enemy_hp <= 0:
		die()

# 2. 敌人死亡
func die():
	print("敌人数据：被击败")
	EventBus.enemy_died.emit(owner)
	owner.queue_free()
