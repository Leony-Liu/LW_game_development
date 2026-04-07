# 定义：State基类
# 
#作用：


class_name State extends Node

# 存储根节点的引用，方便我们在状态里调用玩家的方法或数据
var host: Node 



# 状态进入时调用（比如：刚进入 Idle 状态时，播放待机动画）
func enter( msg :Dictionary = {}) -> void:
	pass

# 状态退出时调用（比如：离开 Idle 准备攻击时，清除某些变量）
func exit() -> void:
	pass

# 每帧执行的逻辑（替代 _process）
func update(delta: float) -> void:
	pass

# 物理帧执行的逻辑（替代 _physics_process）
func physics_update(delta: float) -> void:
	pass
	
# 专门用来接收玩家卡牌输入的逻辑
func handle_input(event: InputEvent) -> void:
	pass
