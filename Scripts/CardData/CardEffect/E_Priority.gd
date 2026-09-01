extends CardEffect
class_name E_Priority

# 行动优先级
@export var priority:int = -1


func execute(source, target):
	return priority
