extends Node

# 1. 定义文件夹寻址路径 (约定大于配置的核心)
# 定义我们要去哪里找声音 (严格对应文件夹结构)
const AUDIO_PATHS = {
	# --- SFX 战斗核心 ---
	"sfx_weapons": "res://Audio/SFX/Weapons/%s.wav",
	"sfx_impacts": "res://Audio/SFX/Impacts/%s.wav",
	"sfx_enemys": "res://Audio/SFX/Enemies/%s.wav",
	"sfx_skills": "res://Audio/SFX/Skills/%s.wav",
	"sfx_player": "res://Audio/SFX/Players/%s.wav",
	# --- UI 与卡牌 ---
	"ui_cards": "res://Audio/UI/Cards/%s.wav",
	"ui_system": "res://Audio/UI/System/%s.wav",
	
	# --- VO 人声 ---
	
	# --- BGM 背景音乐 ---
	
}

func _ready() -> void:
	# 监听全局音频信号
	BattleBus.play_sfx.connect(_on_play_sfx)

func _on_play_sfx(category: String, sound_name: String, global_pos: Vector3 = Vector3.ZERO) -> void:
	# 检查大分类写对没有
	assert(AUDIO_PATHS.has(category), "【音频系统】报错：未知的音频分类 -> " + category)
		
	# 拼接出真正的文件路径
	var target_path = AUDIO_PATHS[category] % sound_name
	
	# ==========================================
	# 💥 严格报错模式（取代了原来的 push_warning 和 return）
	# ==========================================
	# assert 会在条件为 false 时，直接在编辑器里暂停游戏，并标红这一行！
	assert(ResourceLoader.exists(target_path), "【音频系统】致命错误：找不到音频文件 -> " + target_path)
		
	# 加载音频并播放
	var stream = load(target_path)
	if global_pos == Vector3.ZERO:
		_play_2d(stream)
	else:
		_play_3d(stream, global_pos)

# 临时生成 2D 播放器
func _play_2d(stream: AudioStream) -> void:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free) # 播完立刻销毁，保持内存干净

# 临时生成 3D 播放器
func _play_3d(stream: AudioStream, pos: Vector3) -> void:
	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.unit_size = 15.0 # 声音传播距离
	
	# 【修复关键】：先把它加到这个世界里！
	add_child(player) 
	
	# 然后再告诉它应该站在世界的哪个位置！
	player.global_position = pos
	
	player.play()
	player.finished.connect(player.queue_free)
