extends Node3D

@onready var anim_player = $testenemyAnime

# 敌人的核心信号
signal enemy_hit_frame_reached



# 添加下面这三行代码：
func _ready() -> void:
	print("===== 当前敌人拥有的所有动画 =====")
	print(anim_player.get_animation_list())
	print("================================")

func play_idle() -> void:
	anim_player.play("Ual2_test/Zombie_Idle")

func play_attack() -> void:
	if anim_player.is_playing():
		anim_player.stop()
	anim_player.play("Ual2_test/Zombie_Scratch")
	print("视觉管理器：僵尸开始攻击")

# ==========================================
# 动画回调事件 (Animation Callbacks)
# ==========================================
# ⚠️ 注意：这个方法必须在僵尸的 attack 动画的“调用方法轨道”中被打上关键帧！
func hit() -> void:
	enemy_hit_frame_reached.emit()
