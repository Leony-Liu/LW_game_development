## 处理主菜单的开始与退出操作。
## 只负责入口切换，不持有基地、远征或存档状态。
extends Control


# 默认聚焦开始按钮，支持键盘操作。
func _ready() -> void:
	$CenterContainer/Buttons/StartButton.grab_focus()


# 将开始意图交给应用级流程，失败时保留菜单供重试。
func _on_start_button_pressed() -> void:
	if not GameManager.start_game():
		push_error("[MainMenu] 开始失败：玩家数据读取或场景交接未完成，请查看具体错误。")


# 请求正常退出应用。
func _on_quit_button_pressed() -> void:
	get_tree().quit()
