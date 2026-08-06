##物品数据基类
##挂载：全局
##作用：负责读取CSV、查抄物品、搜索时返回物品数据
extends Node

var item_list: Array[ItemData]


##读取CSV
func load_csv(path):
	pass


##随机返回count件物品
func get_random_items(count):
	pass


##根据ID查找物品
func find_item(id):
	pass
