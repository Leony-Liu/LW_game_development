class_name AttributeBuff
extends RefCounted

# 实现的功能：作为纯数据容器，记录影响属性的四个四则运算值。继承RefCounted使其轻量化，不需要挂载在节点树上。
var add_value: float = 0.0
var sub_value: float = 0.0
var mul_value: float = 1.0 # 乘法默认值为1，避免归零
var div_value: float = 1.0 # 除法默认值为1，避免报错

# 使用方法：通过 AttributeBuff.new() 实例化，配置数值后传入 Attribute 脚本。
func _init(add: float = 0.0, sub: float = 0.0, mul: float = 1.0, div: float = 1.0) -> void:
	add_value = add
	sub_value = sub
	mul_value = mul
	div_value = div
