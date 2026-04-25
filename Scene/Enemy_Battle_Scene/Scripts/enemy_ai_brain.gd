# enemy_ai_brain
#
# 基础数值，供机制更改
# 根据抽取的机制生成机制节点

extends Node
class_name EnemyAIBrain

# ==========================================
# 基础数值，供机制更改
# ==========================================
var min_idle_time: float = 2.0  # 最小发呆时间
var max_idle_time: float = 4.0  # 最大发呆时间
var skill_chance: float = 0.2   # 释放技能的概率 (20%)
var combo_count: int = 2        # 连击次数

# ==========================================
# 根据抽取的机制生成机制节点
# ==========================================
# 机制脚本存放路径
const MECHANICS_BASE_DIR = "res://Scene/Enemy_Battle_Scene/Scripts/EnemyMechanics/"
var active_mechanics: Array[Node] = []

# 敌人生成：接收从外部（CSV 或 测试代码）传来的机制名字列表
func initialize(mechanic_names: Array[String]):
	for mech_name in mechanic_names:
		# 动态拼接出绝对路径
		var full_path = MECHANICS_BASE_DIR + mech_name + ".gd"
		
		# 尝试加载脚本资源
		var script_res = load(full_path)
		if script_res:
			# 实例化脚本为节点，并挂载到大脑下面
			var mech_node = script_res.new()
			# 方便在左侧场景树里清晰地看到它
			mech_node.name = mech_name 
			add_child(mech_node)
			active_mechanics.append(mech_node)
			
			# 告诉机制脚本，被强化的敌人是谁
			if mech_node.has_method("init_mechanic"):
				mech_node.init_mechanic(owner) # owner 就是最顶层的 Enemy 根节点
				
		else:
			push_error("敌人AI大脑装配失败：找不到脚本 -> " + full_path)
			
	print(" 敌人AI大脑：装配完毕！当前携带机制数量：", active_mechanics.size())
