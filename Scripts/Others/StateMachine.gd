extends Node
class_name StateMachine


# 导出一个变量，方便在编辑器里直接把默认状态（比如 Idle 节点）拖进来
@export var initial_state: State

# 记录当前正在运行的状态
var current_state: State
# 字典：用来存放所有子状态的引用，格式为 {"Idle": Idle节点实例, "Attack": Attack节点实例}
var states: Dictionary = {}

# ———————————————— ↓ 状态交换机通用部分 ↓ ————————————————
# 遍历状态子节点保存进字典并将根节点传入
func _ready() -> void:
	
	# 稍微延迟一帧初始化，确保父节点以及所有组件都已经准备好
	await owner.ready 
	
	# 遍历当前节点（StateMachine）下的所有子节点
	for child in get_children():
		if child is State:
			# 把子节点按名字存入字典，方便后续通过名字查找
			states[child.name] = child
			# 把场景的根节点传给状态,这样状态脚本里就能直接调用了
			child.host = owner 

	# 检查是否设置了初始状态，如果有，就正式进入它
	if initial_state:
		# 给 initial_state 赋值给 current_state 之前，先调用它的 enter 方法
		initial_state.enter()
		current_state = initial_state
# --- 下面这三个函数的作用是“向下级分发工作” ---
# 如果当前有状态，就把玩家的按键输入传递给当前状态去处理
func _unhandled_input(event: InputEvent) -> void:
	# 如果当前有状态，就把玩家的按键输入传递给当前状态去处理
	if current_state:
		current_state.handle_input(event)
# 把每一帧的运行逻辑传递给当前状态
func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)
# 把物理帧的运行逻辑传递给当前状态
func _physics_process(delta: float) -> void:
	
	if current_state:
		current_state.physics_update(delta)
# 状态切换
func transition_to(target_state_name: String) -> void:
	# 安全检查：如果字典里没有要切换的状态名字，直接报错并退出，防止游戏崩溃
	if not states.has(target_state_name):
		push_error("试图切换到不存在的状态: ", target_state_name)
		return
	# 获取目标状态的节点实例
	var next_state = states[target_state_name]
	# 1. 让当前状态执行退出清理工作
	if current_state:
		current_state.exit()
	# 2. 核心：把当前状态替换为目标状态
	current_state = next_state
	# 3. 让新的状态执行进入逻辑
	current_state.enter()
# ———————————————— ↑ 状态交换机通用部分 ↑ ————————————————


# 接收卡牌信号后判断状态并传数据给idle
func handle_card_played(card_data:Dictionary)->bool:
	if current_state.name == "Idle":
		current_state.handle_card_played(card_data)
		print("状态交换机：成功传输数据到idle")
		return true
	else:
		print("状态交换机：当前状态不能出牌")
		return false
