extends Node
class_name PlayerCalculator

@onready var data:PlayerCombatData = $"../CombatData"
@onready var inventory:PlayerInventory = $"../Inventory"


# 计算所有伤害增益效果
func calculate_outgoing_damage(base_damage: int, card_mult_bonus: float = 0.0) -> int:
	
	# 向背包要【装备子集】
	var equip_stats = inventory.get_total_equipment_stats()
	
	# 固定值区域（加区）
	var flat_atk = equip_stats["flat_attack_bonus"]# 装备-固定值
	
	# 倍率区域（乘区）
	var equip_mult = equip_stats["equip_atk_mult_bonus"]# 装备-倍率
	
	
	# 3. 汇总所有加区（固定值）
	var total_flat_attack = base_damage + flat_atk
	print("玩家计算器：成功汇总加区数值为-%d" %total_flat_attack)
	
	# 4. 汇总所有乘区（极其关键：1.0 基础 + 装备提供 + 卡牌提供 + Buff提供）
	var total_multiplier = 1.0 + equip_mult + card_mult_bonus 
	print("玩家计算器：成功汇总乘区数值为-%d" %total_multiplier)
	
	# 5. 终极一算：总加区 * 总乘区
	var final_damage = total_flat_attack * total_multiplier
	print("玩家计算器：最终伤害结算完成-%d" %final_damage)
	
	return int(final_damage)
