## 处理基地临时远征入口，不管理武器、存档或角色运动。
## 角色控制和相机归复用的 PlayerVisual 组件所有。
extends Node3D

# 只在活动 Base 接收 P，重复切换由应用层门闩阻止。
func _unhandled_input(event: InputEvent) -> void:
	if get_tree().current_scene != self or (event is InputEventKey and event.echo):
		return
	if event.is_action_pressed("start_expedition"):
		get_viewport().set_input_as_handled()
		if not GameManager.start_expedition():
			push_error("[Base] 远征未启动；请检查玩家数据、保存结果及必需场景。")
