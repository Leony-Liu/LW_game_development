class_name CombatAction
extends RefCounted

# 单个属性影响的原子数据结构
class AttributeImpact extends RefCounted:
	var attribute_name: String # 目标属性名称（如 "hp", "shield", "mana"）
	var value: float           # 调整数值（正数为增加，负数为扣减）

	func _init(p_name: String, p_val: float) -> void:
		attribute_name = p_name
		value = p_val

# 行动元数据
var action_name: String = ""
var source_id: String = ""        # 行动发起方 ID（如 "player" 或 "enemy_0"）
var target_id: String = ""        # 行动目标方 ID
var is_player: bool = false       # 是否为玩家行动

# 时间轴调度属性
var trigger_time: int = 0         # 在时间轴上的绝对触发时间戳
var priority: int = 0             # 优先级（同一时间点数值越大越先执行）

# 意图效果载荷集合
var attribute_impacts: Array[AttributeImpact] = [] # 目标属性变更列表（数值调整）
var entity_buffs: Array[AttributeBuff] = []        # 施加给目标实体的状态 Buff 列表
var card_buffs: Array[CardBuff] = []               # 施加给卡牌的 Buff 列表

# 快速添加属性变更记录（如扣血、加盾）
func add_attribute_impact(p_attr_name: String, p_value: float) -> void:
	attribute_impacts.append(AttributeImpact.new(p_attr_name, p_value))

# 挂载实体 Buff
func add_entity_buff(buff: AttributeBuff) -> void:
	entity_buffs.append(buff)

# 挂载卡牌 Buff
func add_card_buff(buff: CardBuff) -> void:
	card_buffs.append(buff)
