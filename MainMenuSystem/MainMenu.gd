## 处理主菜单的开始与退出操作。
## 只负责入口切换，不持有基地、远征或存档状态。
extends Control

const BASE_SCENE_PATH: String = "res://BaseSystem/Base.tscn"


# 默认聚焦开始按钮，支持键盘操作。
func _ready() -> void:
	$CenterContainer/Buttons/StartButton.grab_focus()


# 请求进入已保存的基地场景，失败时保留菜单并报告原因。
func _on_start_button_pressed() -> void:
	var result: Error = get_tree().change_scene_to_file(BASE_SCENE_PATH)
	if result != OK:
		push_error("[MainMenu] 无法进入 %s：%s；保留主菜单。" % [BASE_SCENE_PATH, error_string(result)])


# 请求正常退出应用。
func _on_quit_button_pressed() -> void:
	get_tree().quit()
