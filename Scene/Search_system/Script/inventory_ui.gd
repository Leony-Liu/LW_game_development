##交互UI
##挂载：背包UI节点
##作用：显示玩家背包
class_name InventoryUI
extends Node


##重新生成整个列表
func refresh(items: Array):
	var item_list := get_node("ItemList") as ItemList
	
	item_list.clear()
	
	for item in items:
		if item == null:
			continue
		
		item_list.add_item(item.name, item.icon)
	pass


##更新某一个条目
func update_list():
	refresh(MAPInventoryManager.get_items())
	pass
