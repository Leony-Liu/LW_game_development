#地图管理器
#作用：用于管理地图场景的生成和跳转
extends Node


func _ready() -> void:
	print("地图管理器加载完成")
	EventBus.map_generated.connect
	EventBus.player_change_scence.connect
