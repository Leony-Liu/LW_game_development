##搜索UI控制器
##挂载：搜索UI节点
##作用：显示搜索到的物品列表
class_name SearchUI
extends Control

##根据传入的物品列表重新生成搜索列表界面
func refresh(items: Array):
	var item_list := $ItemList as ItemList

	item_list.clear()

	for item in items:
		if item == null:
			continue

		item_list.add_item(item.name, item.icon)
	pass


##从当前搜索列表移除物品并刷新显示
func remove_item(item):
	SearchManager.current_items.erase(item)
	refresh(SearchManager.current_items)
	pass


##关闭搜索界面通知InteractionManager结束本次交互
func close():
	hide()
	InteractionManager.close_search()
	pass
