extends Node

@export var world_viewport : Node
@export var ui_layer : CanvasLayer

# 【专业做法】：将需要的场景作为变量暴露到检查器
# 在外部直接拖拽赋值，彻底消灭硬编码字符串
@export_group("Default Scenes")
@export var initial_ui_scene: PackedScene

func _ready() -> void:
	# 启动时安全加载
	if initial_ui_scene:
		load_ui_scene(initial_ui_scene)
	else:
		push_error("MAIN节点严重错误：未在检查器中配置 initial_ui_scene！")

# ==========================================
# 场景装载逻辑 (参数改为 PackedScene)
# ==========================================
func load_ui_scene(scene_resource: PackedScene) -> void:
	_clear_container(ui_layer)
	_clear_container(world_viewport)
	
	var ui_instance = scene_resource.instantiate()
	ui_layer.add_child(ui_instance)

func load_world_scene(scene_resource: PackedScene) -> void:
	_clear_container(ui_layer)
	_clear_container(world_viewport)
	
	var world_instance = scene_resource.instantiate()
	world_viewport.add_child(world_instance)

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
