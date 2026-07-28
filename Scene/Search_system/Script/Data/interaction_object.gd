##可交互物体
##挂载：场景中的可交互物体上
##作用：判断物体是否可交互；判断物体是否已经被搜索过
extends Node
class_name InteractableObject

var object_name: String#交互场景物体名字
var searched: bool#是否已被搜索
var loot_table: Array#当前物体使用的掉落表

##开始交互
func interact():
	pass

##生成随机物品
func generate_loot():
	pass
