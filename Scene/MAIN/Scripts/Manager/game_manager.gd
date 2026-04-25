extends Node

@export var scene_holder: Node
@export var battle_scene: PackedScene

var current_scene: Node = null

func _ready() -> void:
	current_scene = scene_holder.get_node("MapScene")
	BattleBus.enter_battle_scene.connect(_on_event_bus_enter_battle_scene)
	pass


func _on_event_bus_enter_battle_scene(hit_enemies: Dictionary, support_enemies: Dictionary) -> void:
	if current_scene:
		current_scene.process_mode = Node.PROCESS_MODE_DISABLED#暂停场景逻辑
		current_scene.visible = false
		
		var battle_scene_instance = battle_scene.instantiate()
		scene_holder.add_child(battle_scene_instance)
	pass
