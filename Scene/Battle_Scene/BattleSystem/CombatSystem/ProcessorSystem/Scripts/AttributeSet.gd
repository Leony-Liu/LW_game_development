class_name AttributeSet
extends Node

# 实现的功能：管理实体所属的所有 Attribute。作为中间层封装属性获取与修改，向 Entity 汇报具体哪个属性发生了变化。
# 使用方法：挂载为 Entity 的子节点。初始化时注册需要的属性。

signal attribute_updated(attr_name: String, old_value: float, new_value: float)

var _attributes: Dictionary = {}

func register_attribute(attr_name: String, initial_value: float) -> void:
	var new_attr = Attribute.new()
	new_attr.initialize(initial_value)
	# 监听下级信号，带上属性名向上级转发
	new_attr.value_changed.connect(func(old, new): attribute_updated.emit(attr_name, old, new))
	_attributes[attr_name] = new_attr

func get_attribute(attr_name: String) -> Attribute:
	return _attributes.get(attr_name)

func get_value(attr_name: String) -> float:
	var attr = get_attribute(attr_name)
	if attr: return attr.get_value()
	return 0.0

# V字通信的核心体现：如果需要配置如“最大生命=基础生命+活力*10”的公式，由同级的共同上级(AttributeSet)进行数据互通。
func bind_custom_formula_to_attribute(target_attr_name: String, formula_callable: Callable) -> void:
	var target_attr = get_attribute(target_attr_name)
	if target_attr:
		target_attr.set_custom_formula(formula_callable)
