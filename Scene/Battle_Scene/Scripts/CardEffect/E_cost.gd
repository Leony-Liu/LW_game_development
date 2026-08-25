extends CardEffect
class_name E_Cost

# 消耗的体力
@export var stanima_cost:int = 0
# 消耗的脑力
@export var mana_cost:int = 0
# 行动值
@export var time_cost:int = 0

func execute(source, target):
	source.stamina -= stanima_cost
	source.stamina -= mana_cost
