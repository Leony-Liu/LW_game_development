class_name Attribute
extends RefCounted

# 实现的功能：单一属性的完整生命周期管理。
# 使用方法：由 AttributeSet 实例化并管理。提供信号供上级监听属性变化。

signal value_changed(old_value: float, new_value: float)

var base_value: float = 0.0
var computed_value: float = 0.0
var buffs: Array[AttributeBuff] = []
var custom_formula: Callable

var _cached_final_value: float = 0.0

func initialize(val: float) -> void:
	base_value = val
	computed_value = val
	_trigger_update()

# 基础运算模块 (修改 computed_value)
func add_base(val: float) -> void: 
	computed_value += val
	_trigger_update()

func sub_base(val: float) -> void: 
	computed_value -= val
	_trigger_update()

func mul_base(val: float) -> void: 
	computed_value *= val
	_trigger_update()

func div_base(val: float) -> void:
	if val != 0: computed_value /= val
	_trigger_update()

# 覆盖模块：注入自定义公式
func set_custom_formula(callable: Callable) -> void:
	custom_formula = callable
	_trigger_update()

# Buff模块
func add_buff(buff: AttributeBuff) -> void:
	if not buffs.has(buff):
		buffs.append(buff)
		_trigger_update()

func remove_buff(buff: AttributeBuff) -> void:
	buffs.erase(buff)
	_trigger_update()

# 最终值计算模块
func get_value() -> float:
	# 若存在自定义公式，则覆盖 computed_value
	var current_base = computed_value
	if custom_formula.is_valid():
		current_base = custom_formula.call()
		
	var final_val = current_base
	# 叠加Buff影响
	for buff in buffs:
		final_val += buff.add_value
		final_val -= buff.sub_value
		final_val *= buff.mul_value
		if buff.div_value != 0:
			final_val /= buff.div_value
			
	return final_val

# 内部状态更新与向上级报告信号
func _trigger_update() -> void:
	var new_val = get_value()
	if new_val != _cached_final_value:
		var old = _cached_final_value
		_cached_final_value = new_val
		value_changed.emit(old, new_val)
