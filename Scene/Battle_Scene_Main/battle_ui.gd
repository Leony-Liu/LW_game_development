extends Control # 或者是 CanvasLayer，取决于你的根节点类型
class_name BattleUIRoot

# 可以把一些需要居中/全屏遮罩的弹窗放在这里管理
# @export var pause_menu: Control
# @export var victory_panel: Control

func _ready() -> void:
	# 确保刚进战斗时，UI 是完全透明/不阻挡 3D 视角的
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 如果有结算界面，可以监听敌人的死亡信号
	# BattleBus.enemy_died.connect(_on_battle_won)
	# EventBus.player_died.connect(_on_battle_lost)

# 统筹全局 UI 快捷键（比如 ESC 暂停）
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # 通常是 ESC 键
		_toggle_pause_menu()

func _toggle_pause_menu() -> void:
	# 这里可以处理调出你的 options_menu 或者是战斗专属的暂停界面
	# 并且通过 get_tree().paused = true 来暂停 3D 世界的时间
	print("UI 根节点：呼出暂停菜单...")
	pass

func _on_battle_won(death_context: String) -> void:
	print("UI 根节点：检测到敌人死亡，准备弹出结算界面！")
	# 弹出胜利面板的逻辑
