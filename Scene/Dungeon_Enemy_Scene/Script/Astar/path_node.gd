#寻路算法的节点类
#作用：存储坐标和路径估算代价
class_name PathNode

var position: Vector2i
var g_cost: float#起点到当前点的代价
var h_cost: float#当前点到终点的代价估值
var f_cost: float#g_cost + h_cost
var parent: PathNode = null#父级节点路径，从终点回溯到起点时用

func _init(pos: Vector2i) -> void:
	position = pos
