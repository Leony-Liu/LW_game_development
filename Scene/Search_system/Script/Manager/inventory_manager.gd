##交互管理器
##挂载：全局
##作用：处理玩家搜索时的交互操作
extends Node

var inventoryt_items: Array = []


func add_item(item: ItemData):
	if item == null:
		return
	
	inventoryt_items.append(item)
	
	UIManager.refresh_inventory(inventoryt_items)
	pass


##删除物品
func remove_item(item: ItemData):
	if item == null:
		return
	
	if item in inventoryt_items:
		inventoryt_items.erase(item)
	
	UIManager.refresh_inventory(inventoryt_items)
	pass


func has_item(item: ItemData) -> bool:
	return item in inventoryt_items


func get_items() -> Array:
	return inventoryt_items
