extends Node3D

@onready var anim_player = $AnimationPlayer

# ==========================================
# 信号定义 (Signals)
# ==========================================
# 攻击伤害判定信号
signal hit_frame_reached 
# 格挡窗口判定信号 (携带判定质量参数)
signal parry_window_changed(quality: String) 

# ==========================================
# 连击系统参数
# ==========================================
var current_combo_step: int = 1
var last_attack_time: int = 0
const COMBO_WINDOW_MSEC: int = 1500 

# ==========================================
# 动作播放接口 (供状态机调用)
# ==========================================
func play_idle() -> void:
	anim_player.play("idle")

func play_attack() -> void:
	var current_time = Time.get_ticks_msec()
	if current_time - last_attack_time <= COMBO_WINDOW_MSEC:
		current_combo_step = 2
	else:
		current_combo_step = 1
		
	last_attack_time = current_time
	var anim_name = "attack" + str(current_combo_step)
	
	if anim_player.is_playing():
		anim_player.stop()
	anim_player.play(anim_name)

# 播放格挡动画
func play_parry() -> void:
	if anim_player.is_playing():
		anim_player.stop()
	# 如果你没有在编辑器里改名字，这里必须写成 "payyr"！建议去编辑器改成 "parry"
	anim_player.play("parry") 

# ==========================================
# 动画回调事件 (Animation Callbacks)
# ⚠️ 这些方法必须在 AnimationPlayer 的调用方法轨道中触发！
# ==========================================
# 触发伤害
func hit() -> void:
	hit_frame_reached.emit()
	BattleBus.play_sfx.emit("sfx_player","attack",self.global_position)# 播放攻击音效

# 更改格挡窗口判定 ("startup", "perfect", "normal", "recovery")
func change_parry_window(quality: String) -> void:
	parry_window_changed.emit(quality)
