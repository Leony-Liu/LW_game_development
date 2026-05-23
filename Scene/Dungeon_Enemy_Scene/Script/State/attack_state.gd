extends DungeonEnemyState

@export var attack: Area2D
var battle_start: bool = false
var can_attack: bool = false
func enter():
	can_attack = true
	print("怪物进入攻击状态")
	enemy.anima_play("attack")
	pass


func update(delta):
	if not can_attack:
		if battle_start:
			print("进入战斗")
			machine.change_state("idle")
			#EventBus.enter_battle_scene.emit()
		else:
			machine.change_state("idle")
	pass


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		can_attack = false
	pass # Replace with function body.


func _on_attack_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		battle_start = true
	pass # Replace with function body.
