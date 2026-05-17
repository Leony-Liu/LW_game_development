# 定义：State基类
# 
#作用：

class_name State extends Node

# 当前场景的根节点
var host: Node 

# 状态进入时调用一次
func enter( msg :Dictionary = {}) -> void:
	pass
	
# 状态退出时调用一次
func exit() -> void:
	pass
	
# 每帧执行的逻辑（电脑卡跟着卡）
func update(delta: float) -> void:
	pass

# 物理帧执行的逻辑（电脑卡不影响）
func physics_update(delta: float) -> void:
	pass

# 仅在本状态下才会生效的玩家输入
func handle_input(event: InputEvent) -> void:
	pass
