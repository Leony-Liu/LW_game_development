extends Node

@export var world_viewport : Node
@export var ui_layer : CanvasLayer


@export_group("Default Scenes")
@export var initial_ui_scene: PackedScene

func _ready() -> void:
	# 启动时加载默认场景
	if initial_ui_scene:
		load_ui_scene(initial_ui_scene)
	else:
		push_error("MAIN节点严重错误：未在检查器中配置 initial_ui_scene！")

# ==========================================
# 单一场景装载逻辑
# ==========================================
# 装载UI场景
func load_ui_scene(scene_resource: PackedScene) -> void:
	# 清空现有全部场景
	_clear_container(ui_layer)
	_clear_container(world_viewport)
	# 装载场景
	var ui_instance = scene_resource.instantiate()
	ui_layer.add_child(ui_instance)
# 装载3D场景
func load_world_scene(scene_resource: PackedScene) -> void:
	# 清空现有全部场景
	_clear_container(ui_layer)
	_clear_container(world_viewport)
	# 装载场景
	var world_instance = scene_resource.instantiate()
	world_viewport.add_child(world_instance)

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

# ==========================================
# 复合场景装载逻辑 (战斗专用：同时加载3D与UI)
# ==========================================
func load_combat_scene(world_resource: PackedScene, ui_resource: PackedScene) -> void:
	# 清空旧场景
	_clear_container(ui_layer)
	_clear_container(world_viewport)
	
	# 实例化并装载 3D 世界
	if world_resource:
		var world_instance = world_resource.instantiate()
		world_viewport.add_child(world_instance)
		
	# 实例化并装载UI场景
	if ui_resource:
		var ui_instance = ui_resource.instantiate()
		ui_layer.add_child(ui_instance)
