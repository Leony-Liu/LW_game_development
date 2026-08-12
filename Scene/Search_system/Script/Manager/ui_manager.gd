##UI管理器
##挂载：全局
##作用：显示和关闭UI
extends Node


##显示背包UI
func show_inventory():
	pass


##显示搜索栏
func show_search():
	var search_ui := get_tree().current_scene.get_node("UILayer/SearchUI") as Control

	search_ui.show()
	pass


##刷新搜索
func refresh_search(items: Array):
	var search_ui := get_tree().current_scene.get_node("UILayer/SearchUI") as SearchUI
	search_ui.refresh(items)
	pass


##刷新背包
func refresh_inventory(items: Array):
	var inventory_ui := get_tree().current_scene.get_node("UILayer/InventoryUI") as InventoryUI
	inventory_ui.refresh(items)
	pass


##关闭UI
func hide_all():
	var search_ui := get_tree().current_scene.get_node("UILayer/SearchUI") as Control
	search_ui.hide()
	pass
