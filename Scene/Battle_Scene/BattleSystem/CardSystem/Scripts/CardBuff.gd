# 存放单张卡牌上的临时增减益数据。引入运算类型枚举，支持“绝对赋值”、“加减”与“乘除”。
class_name CardBuff
extends RefCounted

enum ModifierType { SET, ADD, MULTIPLY }

var buff_id: String
var target_property: String
var mod_type: ModifierType
var value_modifier: float 
var time_left: int = -1 
var count_left: int = -1 

# 初始化Buff实例
func _init(id: String, prop: String, type: ModifierType, mod: float, t_left: int = -1, c_left: int = -1) -> void:
	buff_id = id
	target_property = prop
	mod_type = type
	value_modifier = mod
	time_left = t_left
	count_left = c_left

# 推进时间轴时调用
func tick_time(delta: int) -> bool:
	if time_left == -1: return false
	time_left -= delta
	return time_left <= 0

# 卡牌发生出牌/特定事件时调用
func tick_count() -> bool:
	if count_left == -1: return false
	count_left -= 1
	return count_left <= 0

# 单步运算计算器
func apply_modifier(current_value: float) -> float:
	match mod_type:
		ModifierType.SET:
			return value_modifier
		ModifierType.ADD:
			return current_value + value_modifier
		ModifierType.MULTIPLY:
			return current_value * value_modifier
	return current_value
