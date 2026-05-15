
extends Node3D
class_name PlayerVisualsManager

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var parry_sound = $ParrySound
@onready var attack_sound = $AttackSound
@onready var  get_hit_sound = $GetHitSound

signal hit_frame_reached 
signal parry_window_changed(quality: String) 

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
	
func change_parry_window(quality: String) -> void:
	parry_window_changed.emit(quality)

func  play_parry_sound()->void:
	parry_sound.play()

func  play_attack_sound()->void:
	attack_sound.play()

func play_get_hit_sound()->void:
	get_hit_sound.play()
