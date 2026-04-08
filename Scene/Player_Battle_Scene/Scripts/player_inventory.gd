extends  Node
class_name PlayerInventory


@onready var calculator = $"../Calculator"
@onready var data = $"../CombatData"


var equipment: Dictionary = {
	# 5个固定部位：不存放具体的“物品ID”，而是直接追踪它们的“强化状态”
	"helmet": {"level": 1, "affixes": []}, # 头盔：影响能量恢复
	"chest":  {"level": 1, "affixes": []}, # 胸甲：影响最大生命倍率
	"legs":   {"level": 1, "affixes": []}, # 腿甲：影响体力恢复
	"gloves": {"level": 1, "affixes": []}, # 手套：影响物理/魔法攻击力倍率
	"shoes":  {"level": 1, "affixes": []}, # 鞋子：影响韧性值上限
	
	# 3个饰品槽位：使用数组表示 [槽位0, 槽位1, 槽位2]
	# 因为饰品是局内掉落的实体道具，没装备时就是 null
	"accessories": [null, null, null]
}

# 玩家背包：游戏中玩家拾取的所有游戏道具
var backpack: Array = []

#固定装备效果处理与输出

#饰品及道具的效果处理与输出
