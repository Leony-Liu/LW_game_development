##搜索UI控制器
##挂载：搜索UI节点
##作用：显示搜索到的物品列表
extends Node
class_name SearchUI


##根据传入的物品列表重新生成搜索列表界面
func refresh(items):
	pass


##从当前搜索列表移除物品并刷新显示
func remove_item(item):
	pass


##关闭搜索界面通知InteractionManager结束本次交互
func close():
	pass
