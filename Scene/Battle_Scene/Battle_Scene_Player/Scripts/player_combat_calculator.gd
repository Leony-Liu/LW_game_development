# player_combat_calculator
# 计算所有玩家输出增益

extends Node
class_name PlayerCalculator

@onready var data:PlayerCombatData = $"../CombatData"
@onready var inventory:PlayerInventory = $"../Inventory"

# 计算方法，返回最终伤害
func calculate_outgoing_damage(base_damage: int, card_mult_bonus: float = 0.0) -> int:
	
	# 装备加成
	var equip_stats = inventory.get_total_equipment_stats() 
	var flat_atk = equip_stats["flat_attack_bonus"]
	var equip_mult = equip_stats["equip_atk_mult_bonus"]
	
	# ================= 核心新增：动态获取全新 Buff =================
	var bonus_dmg = data.get_buff_value("charge") 
	var timed_atk_buff = data.get_buff_value("attack_surge") 
	
	# 新增：下次攻击强化 (残击、压步)
	var next_atk_flat = data.get_buff_value("next_atk_flat") 
	var next_atk_mult = data.get_buff_value("next_atk_mult") 
	
	# 新增：限时状态增益 (蓄力5秒加伤)
	var timed_dmg_up = data.get_buff_value("damage_up_percent")
	# =========================================================
	
	# ———————————— 汇总所有加区（固定值）————————————
	# 基础伤害 + 装备加成 + 蓄力增益 + 下次攻击附加数值
	var total_flat_attack = base_damage + flat_atk + bonus_dmg + next_atk_flat
	
	# ———————————— 汇总所有乘区（百分比）————————————
	# 1.0 基础 + 装备倍率 + 卡牌倍率 + 限时增幅 + 下次攻击倍率 + 限时伤害加成
	var total_multiplier = 1.0 + equip_mult + card_mult_bonus + timed_atk_buff + next_atk_mult + timed_dmg_up
	
	# 终极核算：总加区 * 总乘区
	var final_damage = total_flat_attack * total_multiplier
	print("玩家计算器：最终伤害结算完成-%d (加区:%d, 乘区:%f)" % [final_damage, total_flat_attack, total_multiplier])
	
	return int(final_damage)
