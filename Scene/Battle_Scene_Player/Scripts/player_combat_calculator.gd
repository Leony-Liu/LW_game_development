# player_combat_calculator
#
# 计算所有玩家输出增益

extends Node
class_name PlayerCalculator

#绑定同级节点
@onready var data:PlayerCombatData = $"../CombatData"
@onready var inventory:PlayerInventory = $"../Inventory"


# ==========================================
# 计算所有玩家输出增益
# ==========================================

# 计算方法，返回最终伤害
func calculate_outgoing_damage(base_damage: int, card_mult_bonus: float = 0.0) -> int:
	
	# 装备加成
	var equip_stats = inventory.get_total_equipment_stats() # 调用背包中计算装备加成的方法
	var flat_atk = equip_stats["flat_attack_bonus"]# 装备-固定值
	var equip_mult = equip_stats["equip_atk_mult_bonus"]# 装备-倍率
	
	# ================= 核心新增：动态获取 Buff =================
	var bonus_dmg = data.get_buff_value("charge") # 获取蓄力附加的固定伤害值
	var timed_atk_buff = data.get_buff_value("attack_surge") # 获取攻击增幅的乘区倍率
	# =========================================================
	
	# ———————————— 汇总所有加区（固定值）————————————
	# 基础伤害 + 装备加成 + 蓄力带来的增益
	var total_flat_attack = base_damage + flat_atk + bonus_dmg
	print("玩家计算器：成功汇总加区数值为-%d" % total_flat_attack)
	
	# ———————————— 汇总所有乘区（百分比）————————————
	# 1.0 基础 + 装备倍率 + 卡牌自带倍率 + 技能限时增幅倍率
	var total_multiplier = 1.0 + equip_mult + card_mult_bonus + timed_atk_buff
	print("玩家计算器：成功汇总乘区数值为-%f" % total_multiplier)
	
# ... 前面算装备和 Buff 提取的代码保留 ...
	
	# 终极核算：总加区 * 总乘区
	var final_damage = total_flat_attack * total_multiplier
	print("玩家计算器：最终伤害结算完成-%d" % final_damage)
	
	# ⚠️ 把原来这里 if active_buffs.has("charge") 的逻辑彻底删掉！
	
	return int(final_damage)
