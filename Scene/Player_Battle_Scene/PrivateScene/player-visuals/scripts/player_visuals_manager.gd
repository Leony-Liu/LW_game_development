
extends Node2D
class_name PlayerVisualsManager

@onready var anim_player: AnimationPlayer = $AnimationPlayer

signal hit_frame_reached 

# 播放待机动画
func play_idle() -> void:
	anim_player.play("idle") 

# 播放攻击动画
func play_attack() -> void:
	anim_player.play("attack") 

# 播放格挡/弹反动画
func play_parry() -> void:
	anim_player.play("parry") 

func hit()->void:
	hit_frame_reached.emit()
