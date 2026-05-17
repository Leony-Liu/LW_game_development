# player_inventory
#
# 定义装备字典
# 装备升级与增益汇总
# 死亡惩罚与重置

extends Node
class_name PlayerInventory

# ==========================================
# 数据部分
# ==========================================

# 玩家装备字典
var equipment: Dictionary = {
	# 5个固定部位：等级、强化词条（初始等级和词条都为空）
	"helmet": {"level": 0, "affixes": []}, 
	"chest":  {"level": 0, "affixes": []}, 
	"legs":   {"level": 0, "affixes": []}, 
	"gloves": {"level": 0, "affixes": []}, 
	"shoes":  {"level": 0, "affixes": []}, 
	
	# 3个饰品槽位：局内掉落的实体道具
	"accessories": [null, null, null]
}

# 局内战术背包：存放掉落的备用饰品、强化材料等
var backpack: Array = []


func _ready() -> void:
	# 接收到玩家死亡信号后执行清理装备的方法
	EventBus.player_died.connect(reset_equipment_on_death)

# ==========================================
# 装备升级与增益汇总
# ==========================================

# 1. 升级指定部位的装备
func upgrade_equipment(slot_name: String) -> void:
	# 先筛选装备名称不是“饰品”的装备
	if equipment.has(slot_name) and slot_name != "accessories":
		# 若未满级（5级）
		if equipment[slot_name]["level"] < 5:
			# 装备等级+1
			equipment[slot_name]["level"] += 1
			print("背包系统：", slot_name, " 升级成功！当前等级：", equipment[slot_name]["level"])
		else:
			# 已满级
			print("背包系统：", slot_name, " 已达到最高等级(5级)！")

# 2. 汇总装备增益（给 Calculator 和 CombatData 提供的汇总面板）
func get_total_equipment_stats() -> Dictionary:
	# 创建基础增益统计字典
	var stats: Dictionary = {
		"defense_bonus_percent": 0.0,  # 额外防御力百分比 (0.0 = 0%)
		"max_hp_multiplier": 1.0,      # 最大生命值倍率 (1.0 = 原始生命)
		"flat_attack_bonus": 0.0,      # 装备加区：固定攻击力
		"equip_atk_mult_bonus": 0.0,   # 装备乘区子集：额外攻击倍率
		"stamina_regen_bonus": 0.0,    # 额外体力恢复值
		"mana_regen_bonus": 0.0,       # 额外能量恢复值
		"poise_bonus": 0.0             # 额外韧性上限
	}
	# 依次检查玩家装备字典内的各个部位等级
	var slots = ["helmet", "chest", "legs", "gloves", "shoes"]
	for slot in slots:
		var level = equipment[slot]["level"]
		# 0级没有任何效果，直接跳过计算
		if level == 0:
			continue
		# 只要有等级，每级提供 2% 的防御力加成
		stats["defense_bonus_percent"] += level * 0.02
		# 部位专属属性：根据不同部位，给予特化增益
		match slot:
			# 胸甲（每级增加20%生命值倍率，最高100%）
			"chest":
				stats["max_hp_multiplier"] += level * 0.20
			# 手套（每级增加10%伤害加成，最高50%）
			"gloves":
				stats["attack_multiplier"] += level * 0.10
			# TODO 腿甲（每级增加体力恢复）！！！暂时数值不合理
			"legs":
				stats["stamina_regen_bonus"] += level * 5.0
			# TODO 头盔（每级增加能力恢复）！！！暂时数值不合理
			"helmet":
				stats["mana_regen_bonus"] += level * 2.0
			# TODO 鞋子（韧性增加）！！！ 韧性系统未制作
			"shoes":
				stats["poise_bonus"] += level * 10.0
				
	return stats


# ==========================================
# 精炼词条逻辑 (占位测试版)
# ==========================================
#
## 给指定部位精炼出一个固定词条（未来接入 CSV 随机库）
#func refine_equipment(slot_name: String) -> void:
	#if equipment.has(slot_name) and slot_name != "accessories":
		#var mock_affix = {
			#"effect_name": "bonus_phy_atk", # 词条效果：增加物理攻击
			#"base_value": 10,               # 基础增加 10 点
			#"affix_level": 1                # 词条自身的强化等级
		#}
		#equipment[slot_name]["affixes"].append(mock_affix)
		#print("背包系统：", slot_name, " 精炼成功！新增固定词条：", mock_affix)
#

# ==========================================
# 饰品穿脱逻辑
# ==========================================
#
## 装备饰品 (尝试放入 0, 1, 2 槽位中空闲的那个)
#func equip_accessory(accessory_data: Dictionary) -> bool:
	#for i in range(equipment["accessories"].size()):
		#if equipment["accessories"][i] == null:
			#equipment["accessories"][i] = accessory_data
			#print("背包系统：成功装备饰品到槽位 ", i, "：", accessory_data["name"])
			## TODO: 通知 EffectManager / BuffManager 给玩家挂上饰品的被动效果
			#return true
			#
	#print("背包系统：饰品槽已满！请先卸下饰品。")
	#return false
#

# ==========================================
# 死亡惩罚与重置
# ==========================================

# 1. 死亡清空饰品栏及装备等级和精炼
func reset_equipment_on_death() -> void:
	print("背包系统：执行死亡惩罚！装备强化归零，饰品及背包物资丢失。")
	for slot in equipment:
		if slot == "accessories":
			# 清空饰品
			equipment[slot] = [null, null, null]
		else:
			# 清空装备等级与精炼词条
			equipment[slot]["level"] = 0
			equipment[slot]["affixes"].clear()
			
	# 清空局内背包物资
	backpack.clear()
