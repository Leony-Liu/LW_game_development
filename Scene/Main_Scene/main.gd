extends Node

@export var active_system_holder: Node
@export var initial_system_scene: PackedScene

var active_system: Node


func _ready() -> void:
	# 检查
	if initial_system_scene == null:
		push_error("MAIN：未配置 initial_system_scene。")
		return

	load_system_scene(initial_system_scene)


func load_system_scene(
	scene_resource: PackedScene,
	context: Dictionary = {}
) -> void:
	# 检查
	if scene_resource == null:
		push_error("MAIN：尝试加载空的 PackedScene。")
		return

	# 立即把旧系统移出场景树，避免它和新系统在同一帧继续接收输入或信号。
	if is_instance_valid(active_system):
		if active_system.get_parent() == active_system_holder:
			active_system_holder.remove_child(active_system)

		active_system.queue_free()
		active_system = null

	active_system = scene_resource.instantiate()
	active_system_holder.add_child(active_system)

	# 可选的统一初始化接口。
	if active_system.has_method("enter_system"):
		active_system.call_deferred("enter_system", context)
