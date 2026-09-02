# 管理实体所属的所有 Attribute。作为中间层封装属性获取与修改，向 Entity 汇报具体哪个属性发生了变化。
class_name AttributeSet
extends Node


signal attribute_updated(attribute_name: String, old_value: float, new_value: float)

var _attributes: Dictionary = {}

# 实例化一个 Attribute
func register_attribute(attribute_name: String, initial_value: float) -> void:
	var new_attr = Attribute.new()
	new_attr.initialize(initial_value)
	# 监听下级信号，带上属性名向上级转发
	new_attr.value_changed.connect(func(old, new): attribute_updated.emit(attribute_name, old, new))
	_attributes[attribute_name] = new_attr

# 外部方法，读取一个 Attribute
func get_attribute(attribute_name: String) -> Attribute:
	return _attributes.get(attribute_name)

# 外部方法，读取 Attribute 当前数值
func get_value(attribute_name: String) -> float:
	var attr = get_attribute(attribute_name)
	if attr: return attr.get_value()
	return 0.0

# 通过 dependencies 数组，实现跨属性的自动化联动。
func bind_custom_formula_to_attribute(target_attribute_name: String, formula_callable: Callable, dependencies: Array = []) -> void:
	var target_attr = get_attribute(target_attribute_name)
	if not target_attr:
		return
		
	# 1. 注入公式
	target_attr.set_custom_formula(formula_callable)
	
	# 2. 中介监听：遍历所有依赖属性
	for dep_name in dependencies:
		var dep_attr = get_attribute(dep_name)
		if dep_attr:
			# 改用标准多行 Lambda 语法，避免解析器报错
			dep_attr.value_changed.connect(
				func(_old, _new):
					target_attr._trigger_update()
			)
