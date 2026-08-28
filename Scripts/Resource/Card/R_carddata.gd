extends Resource
class_name CardData

# 基础信息
@export_category("基本信息")
## 身份
@export var id : int
## 名称
@export var name : String
## 描述
@export_multiline var description: String
##卡牌类型
@export var card_type: CardType
## 这张卡拥有的效果
@export var effects:Array[CardEffect]

# 卡牌类型
enum CardType{
	Attack,
	Skill,
	Power
}

# 执行效果数组内的所有卡牌效果脚本
func play(source, target):
	for effect in effects:
		effect.execute(source, target)
