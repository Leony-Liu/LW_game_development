##搜索管理器
##挂载：全局
##作用：生成搜索列表、保存当前搜索物品、拿取物品、删除物品、刷新UI
extends Node

var current_items: Array[ItemData] = []#保存当前搜索界面的物品数据

@export var default_item_count: int = 5#默认一次搜索生成的物品数量

var rng:= RandomNumberGenerator.new()


##初始化搜索
func open_search(object: InteractableObject):
	generate_items(object)
	
	UIManager.refresh_search(current_items)
	pass


##调用ItemDatabase随机生成物品
func generate_items(object: InteractableObject):
	# 引用该物体的剩余物品，拿取时同步修改物体保存的结果。
	current_items = object.generate_loot()
	pass


##玩家点击拿取物品
func take_item(item: ItemData):
	
	#判断交互物品是否存在搜索列表
	if item == null or not current_items.has(item):
		return
	
	#添加物品到玩家背包
	MAPInventoryManager.add_item(item)
	
	#物品从搜索列表移除
	current_items.erase(item)
	
	#刷新搜索UI
	UIManager.refresh_search(current_items)
	pass


##获取当前物体搜索列表
func get_items()-> Array[ItemData]:
	return current_items


##关闭搜索时解除当前列表引用，保留物体的剩余物品
func clear():
	current_items = []
	pass
