##搜索管理器
##挂载：全局
##作用：生成搜索列表、保存当前搜索物品、拿取物品、删除物品、刷新UI
extends Node

var current_items: Array#保存当前搜索界面的物品数据


##初始化搜索
func open_search():
	pass


##调用ItemDatabase随机生成物品
func generate_items():
	pass


##玩家点击拿取物品
func take_item(item):
	pass


##关闭搜索时清空当前搜索结果
func clear():
	pass
