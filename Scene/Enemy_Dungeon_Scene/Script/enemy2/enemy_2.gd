extends CharacterBody2D
class_name Enemy
@export var speed := 50
@export var player_node: Player
@export var navigation_agent_2d: NavigationAgent2D
@export var anima: AnimationPlayer
@export var movement: GungeonEnemeyMoveMent
@export var my_info: DungeonEnemyInfo



#func _physics_process(delta: float) -> void:
	#print(player_node)
	#if not navigation_agent_2d.is_navigation_finished():
		#var direction = to_local(navigation_agent_2d.get_next_path_position()).normalized()
		#navigation_agent_2d.set_velocity(direction * speed)


func anima_play(anim_name: String):
	anima.play(anim_name)
	pass


func get_my_room() -> BSPNode:
	return my_info.MyNode


func get_my_mapInfo() -> MapInfo:
	return my_info.map_info


func get_player() -> Player:
	return player_node


#func _on_timer_timeout() -> void:
	#if player_node != null:
		#navigation_agent_2d.target_position = player_node.position
	#pass # Replace with function body.


#func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	#velocity = safe_velocity
	#move_and_slide()
	#pass # Replace with function body.


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_node = body
	pass # Replace with function body.


func _on_area_2d_body_exited(body: Node2D) -> void:
	player_node = null
	pass # Replace with function body.
