extends Node
class_name PlayerInventory

# ==========================================
# 核心数据：装备与背包
# ==========================================
var equipment: Dictionary = {
	# 5个固定部位：直接追踪它们的“强化状态”和“精炼词条”
	# 初始设定为 1 级（0级代表死亡后失去加成/未激活）
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
	EventBus.player_died.connect(reset_equipment_on_death)# 接收到玩家死亡信号后清理装备等级

# ==========================================
# 系统 A：装备升级与增益汇总 (核心公式驱动)
# ==========================================

# 升级指定部位的装备
func upgrade_equipment(slot_name: String) -> void:
	if equipment.has(slot_name) and slot_name != "accessories":
		# 假设满级是 5 级
		if equipment[slot_name]["level"] < 5:
			equipment[slot_name]["level"] += 1
			print("背包系统：", slot_name, " 升级成功！当前等级：", equipment[slot_name]["level"])
		else:
			print("背包系统：", slot_name, " 已达到最高等级(5级)！")

# 【核心接口】：给 Calculator 和 CombatData 提供的一键汇总面板
func get_total_equipment_stats() -> Dictionary:
	var stats: Dictionary = {
		"defense_bonus_percent": 0.0,  # 额外防御力百分比 (0.0 = 0%)
		"max_hp_multiplier": 1.0,      # 最大生命值倍率 (1.0 = 原始生命)
		"flat_attack_bonus": 0.0,      # 装备加区：固定攻击力
		"equip_atk_mult_bonus": 0.0,   # 装备乘区子集：额外攻击倍率
		"stamina_regen_bonus": 0.0,    # 额外体力恢复值
		"mana_regen_bonus": 0.0,       # 额外能量恢复值
		"poise_bonus": 0.0             # 额外韧性上限
	}
	
	var slots = ["helmet", "chest", "legs", "gloves", "shoes"]
	
	for slot in slots:
		var level = equipment[slot]["level"]
		
		# 0级没有任何效果，直接跳过计算
		if level == 0:
			continue
			
		# 全局基础属性：只要有等级，每级提供 2% 的防御力加成
		stats["defense_bonus_percent"] += level * 0.02
		
		# 部位专属属性：根据不同部位，给予特化增益
		match slot:
			# 胸甲（每级增加20%生命值倍率，最高100%）
			"chest":
				stats["max_hp_multiplier"] += level * 0.20
			# 手套（每级增加10%伤害加成，最高50%）
			"gloves":
				stats["attack_multiplier"] += level * 0.10
			# 腿甲（每级增加体力恢复）
			"legs":
				stats["stamina_regen_bonus"] += level * 5.0
			# 头盔（每级增加能力恢复）
			"helmet":
				stats["mana_regen_bonus"] += level * 2.0
			# 鞋子（韧性增加）
			"shoes":
				stats["poise_bonus"] += level * 10.0
				
	return stats


# ==========================================
# 系统 B：精炼词条逻辑 (占位测试版)
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
# 系统 C：饰品穿脱逻辑
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
# 系统 D：死亡惩罚与重置
# ==========================================

# 这个方法应该由 EventBus 的 player_died 信号触发调用
func reset_equipment_on_death() -> void:
	print("背包系统：执行死亡惩罚！装备强化归零，饰品及背包物资丢失。")
	
	for slot in equipment:
		if slot == "accessories":
			# 爆出身上携带的饰品
			equipment[slot] = [null, null, null]
		else:
			# 基础五件套降回 0 级，清空精炼
			equipment[slot]["level"] = 0
			equipment[slot]["affixes"].clear()
			
	# 清空局内背包物资
	backpack.clear()
