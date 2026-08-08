###交互管理器
###挂载：全局
###作用：整个交互系统的入口,判断是否存在可交互物体、调用物体交互、打开搜索界面、关闭搜索界面
#extends Node
#
### 当前可以交互的对象
#var current_object: InteractableObject = null
#
#
### 设置当前交互对象
#func set_current_object(object: InteractableObject) -> void:
	#current_object = object
#
#
### 离开交互范围
#func clear_current_object(object: InteractableObject) -> void:
	#if current_object == object:
		#current_object = null
#
#
### 玩家按下交互按键时调用
#func try_interact() -> void:
	## 没有交互目标
	#if current_object == null:
		#return
	## 调用交互对象
	#current_object.interact()
	## 打开搜索UI
	#open_search()
#
#
### 打开搜索界面
#func open_search() -> void:
	#UIManager.show_search()
	## UI音效可以写在这里
#
#
### 关闭搜索界面
#func close_search() -> void:
	#UIManager.hide_search()
	#current_object = null
