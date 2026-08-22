extends Node


@export var  scene_holder : Node

# 同步挂载节点，加载默认场景
func _ready() -> void:
	
	SceneManager.scene_holder = scene_holder
	EventBus.load_scene.emit("main_menu")
