extends StaticBody3D

@export var prompt_text: String = "OPEN THE DOOR [E]"#UI文字
var is_player_in_range: bool = false#玩家是否进入

func _ready() -> void:
	pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		is_player_in_range = true
		# 通知 UI 层显示提示
		EventBus.interaction_prompt_requested.emit(true, prompt_text, self)
		print("UI信号已发出")
	pass


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		is_player_in_range = false
		# 通知 UI 层隐藏提示
		EventBus.interaction_prompt_requested.emit(false, "", self)
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if is_player_in_range and event.is_action_pressed("interact"): # 需要在输入映射定义 interact (如 E 键)
		open_chest()

func open_chest():
	print("箱子已开启，掉落卡牌！")
	# 逻辑：播放动画、掉落物品、自毁或改变状态
	EventBus.interaction_prompt_requested.emit(false, "", self)
	# queue_free() 或播放打开动画
	pass
