## 展示远征战斗结果，并将按钮操作上报给协调器。
## 不修改世界、战斗或场景状态。
class_name ExpeditionResultUI
extends CanvasLayer

signal victory_confirmed
signal restart_requested

@export var victory_panel: Control
@export var game_over_panel: Control
@export var confirm_button: Button
@export var restart_button: Button


# 校验场景引用并连接结果按钮。
func _ready() -> void:
	assert(victory_panel != null and game_over_panel != null, "ExpeditionResultUI: 缺少结果面板。")
	assert(confirm_button != null and restart_button != null, "ExpeditionResultUI: 缺少结果按钮。")
	victory_panel.hide()
	game_over_panel.hide()
	confirm_button.pressed.connect(_on_confirm_pressed)
	restart_button.pressed.connect(_on_restart_pressed)


# 展示对应结果，并将键盘焦点交给唯一操作按钮。
func show_result(is_player_victory: bool) -> void:
	victory_panel.visible = is_player_victory
	game_over_panel.visible = not is_player_victory
	if is_player_victory:
		confirm_button.grab_focus()
	else:
		restart_button.grab_focus()


# 结果处理成功后隐藏面板。
func hide_result() -> void:
	victory_panel.hide()
	game_over_panel.hide()


# 将胜利确认上报给 ExpeditionManager。
func _on_confirm_pressed() -> void:
	victory_confirmed.emit()


# 沿用现有信号接口，上报失败后的返回基地确认。
func _on_restart_pressed() -> void:
	restart_requested.emit()
