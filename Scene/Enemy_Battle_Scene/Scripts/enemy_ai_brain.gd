extends Node
class_name EnemyAIBrain

# ==========================================
#  AI 行为参数黑板 (Blackboard)
# 这些是怪物的默认性格，等待被具体的“机制芯片”修改
# ==========================================
var min_idle_time: float = 2.0  # 最小发呆时间
var max_idle_time: float = 4.0  # 最大发呆时间
var skill_chance: float = 0.2   # 释放技能的概率 (20%)
var combo_count: int = 1        # 连击次数

# 机制脚本存放路径
const MECHANICS_BASE_DIR = "res://Scene/Enemy_Battle_Scene/Scripts/EnemyMechanics/"
var active_mechanics: Array[Node] = []


# 装配车间入口：接收从外部（CSV 或 测试代码）传来的机制名字列表
func initialize(mechanic_names: Array[String]):
	for mech_name in mechanic_names:
		# 动态拼接出绝对路径
		var full_path = MECHANICS_BASE_DIR + mech_name + ".gd"
		
		# 尝试加载脚本资源
		var script_res = load(full_path)
		if script_res:
			# 实例化脚本为节点，并挂载到大脑下面
			var mech_node = script_res.new()
			mech_node.name = mech_name # 方便我们在左侧场景树里清晰地看到它
			add_child(mech_node)
			active_mechanics.append(mech_node)
			
			# 【极其关键】告诉机制脚本，它的宿主（被强化的敌人）是谁
			if mech_node.has_method("init_mechanic"):
				mech_node.init_mechanic(owner) # owner 就是最顶层的 Enemy 根节点
				
		else:
			push_error("AI大脑装配失败：找不到脚本 -> " + full_path)
			
	print(" AI大脑：装配完毕！当前携带机制数量：", active_mechanics.size())
