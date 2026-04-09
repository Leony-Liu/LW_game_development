# buff_defense.gd (放在 Mechanics 文件夹下)
# 这是一个独立的机制组件
extends Node

# 这个方法会被 AIBrain 在实例化时自动调用
func init_mechanic(host_enemy: Node):
	# 顺藤摸瓜找到敌人的属性池
	var combat_data = host_enemy.get_node_or_null("Data/CombatData")
	
	if combat_data:
		# 强行修改敌人的面板数据！
		combat_data.enermy_defense += 50
		print("⚡ 机制 [坚硬甲壳] 已生效：宿主防御力永久 +50！当前防御：", combat_data.enermy_defense)
