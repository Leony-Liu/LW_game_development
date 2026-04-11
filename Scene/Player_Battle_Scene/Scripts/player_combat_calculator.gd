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
	
	# ———————————— 汇总所有加区（固定值）————————————
	var total_flat_attack = base_damage + flat_atk
	print("玩家计算器：成功汇总加区数值为-%d" %total_flat_attack)
	
	# ———————————— 汇总所有乘区（百分比）————————————
	var total_multiplier = 1.0 + equip_mult + card_mult_bonus #（极其关键：1.0 基础 + 装备提供 + 卡牌提供 + Buff提供）
	print("玩家计算器：成功汇总乘区数值为-%d" %total_multiplier)
	
	# 终极核算：总加区 * 总乘区
	var final_damage = total_flat_attack * total_multiplier
	print("玩家计算器：最终伤害结算完成-%d" %final_damage)
	
	return int(final_damage)
