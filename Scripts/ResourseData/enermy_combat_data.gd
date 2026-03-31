# 定义：敌人数据
# 作用：
# 存储敌人的数据
#


extends Resource
class_name EnermyCombatData

# —————— 1. 基础面板（裸装属性） ——————
@export var enermy_hp: int = 100 # 基础生命
@export var enermy_defense: int = 0 # 基础防御力


@export var physical_damage_multiplier: int = 0 # 物理伤害倍率
@export var magical_damage_multiplier: int = 0 # 物理伤害倍率
@export var real_damage_multiplier: int = 0 # 真实伤害倍率
