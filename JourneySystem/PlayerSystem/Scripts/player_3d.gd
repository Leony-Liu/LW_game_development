extends CharacterBody3D
class_name Player

@onready var interaction_area: Area3D = $InteractionArea


func _ready() -> void:
	interaction_area.area_entered.connect(_on_interaction_area_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_area_exited)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interact()
	pass


func interact():
	InteractionManager.try_interact()




func _on_interaction_area_area_entered(area: Area3D) -> void:
	if area is InteractableObject:
		InteractionManager.current_object = area
		print("Player:检测到可搜索物体")
	pass # Replace with function body.


func _on_interaction_area_area_exited(area: Area3D) -> void:
	if area == InteractionManager.current_object:
		InteractionManager.current_object = null
	pass # Replace with function body.
