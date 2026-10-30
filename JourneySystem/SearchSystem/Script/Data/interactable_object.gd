##可交互物体
##挂载：场景中的可交互物体上
##作用：判断物体是否可交互；判断物体是否已经被搜索过
class_name InteractableObject
extends Area3D

var object_name: String#交互场景物体名字
var searched: bool = false#是否已被搜索
var loot_table: Array = []#当前物体使用的掉落表
var remaining_items: Array[ItemData] = []#该物体搜索后剩余的物品

##开始交互
func interact():
	InteractionManager.open_search(self)
	print("InteractableObject:开始交互")
	pass

##生成随机物品
func generate_loot() -> Array[ItemData]:
	if searched:
		return remaining_items
	
	searched = true
	
	if loot_table.is_empty():
		remaining_items = ItemDataBase.get_random_items(randi_range(1, 3))
		return remaining_items
	
	for item_id in loot_table:
		var item: ItemData = ItemDataBase.find_item(item_id)
		if item != null:
			remaining_items.append(item)
	return remaining_items
	pass
