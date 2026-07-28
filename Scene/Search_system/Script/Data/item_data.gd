##物品数据
##挂载：数据类，无需挂载
##作用：保存单个物品的数据
class_name ItemData

var id: int#物品ID
var name: String#物品名称
var type: String#物品种类
var rarity : int#稀有度，决定UI颜色
var weight : int#权重
var icon : Texture2D#图片
var description : String#物品描述
