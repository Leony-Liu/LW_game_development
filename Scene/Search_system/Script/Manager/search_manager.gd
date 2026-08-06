##搜索管理器
##挂载：全局
##作用：生成搜索列表、保存当前搜索物品、拿取物品、删除物品、刷新UI
extends Node

var current_items: Array[ItemData] = []#保存当前搜索界面的物品数据
var current_container: InteractableObject = null#当前正在搜索的物体
@export var default_item_count: int = 5#默认一次搜索生成的物品数量

var rng:= RandomNumberGenerator.new()


##初始化搜索
func open_search(container: InteractableObject):
	current_container = container
	
	generate_items()
	
	UIManager.show_search(current_items)
	pass


##调用ItemDatabase随机生成物品
func generate_items():
	current_items.clear()
	
	current_items = ItemDataBase.get_random_items(default_item_count)
	pass


##玩家点击拿取物品
func take_item(item):
	
	#判断交互物品是否存在搜索列表
	if item not in current_items:
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


##关闭搜索时清空当前搜索结果
func clear():
	current_items.clear()
	current_container = null
	pass
