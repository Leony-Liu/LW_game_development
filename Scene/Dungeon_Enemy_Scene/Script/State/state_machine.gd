#怪物状态机
class_name DungeonEnemyStateMachine
extends Node

var current_state: DungeonEnemyState
var states: Dictionary = {}


func _ready() -> void:
	#敌人状态初始化
	for child in get_children():#返回StateMachine的所有子节点，类型为数组
		if child is DungeonEnemyState:
				states[child.name.to_lower()] = child#将子节点名称存进字典，方便后期修改
				child.machine = self#在状态子节点脚本中不用声明新的machine变量就可以直接用
				child.enemy = owner#状态子节点锁定它归属的敌人根节点
	print(states.keys())
	
	current_state = states["idle"]
	current_state.enter()

#怪物状态转变方法
func change_state(new_state_name: String):
	#防止传回位置状态
	if not states.has(new_state_name): 
		print("怪物状态机：未知状态")
		return
	
	current_state.exit()
	current_state = states[new_state_name]
	current_state.enter()


#普通循环
func _process(delta: float) -> void:
	current_state.update(delta)


#处理物理效果的循环
func _physics_process(delta: float) -> void:
	current_state.physics_update(delta)
