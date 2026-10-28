## 管理基地交互提示、远征确认和牌组窗口的显示。
## 向 Base 上报用户意图，不访问玩家数据或应用流程。
extends CanvasLayer

signal expedition_confirmed
signal modal_close_requested
signal card_transfer_requested(source_id: String, uid: String)

# 在 Base 接收交互前检查动态卡片场景，必需内容不可静默缺失。
func validate_configuration() -> bool:
	return get_node_or_null("%Prompt") != null and get_node_or_null("%ExpeditionConfirmation") != null and get_node_or_null("%DeckEditor") != null and %DeckEditor.card_scene != null

# 连接独立 UI 模块，按钮不直接调用 GameManager。
func _ready() -> void:
	%ExpeditionConfirmation.confirmed.connect(expedition_confirmed.emit)
	%ExpeditionConfirmation.canceled.connect(modal_close_requested.emit)
	%ExpeditionConfirmation.close_requested.connect(modal_close_requested.emit)
	%DeckEditor.close_requested.connect(modal_close_requested.emit)
	%DeckEditor.transfer_requested.connect(card_transfer_requested.emit)

# 提示只有一个，由 Base 决定最近交互目标。
func show_prompt(message: String) -> void:
	%Prompt.text = message
	%Prompt.visible = not message.is_empty()

# E 已由 Base 消费；确认只由独立按钮触发。
func show_confirmation() -> void:
	show_prompt("")
	%ExpeditionConfirmation.dialog_text = "是否进入远征？"
	%ExpeditionConfirmation.popup_centered(Vector2i(440, 180))

# 将当前武器传给牌组视图，不初始化任何玩家数据。
func show_editor(weapon: WeaponInstance) -> void:
	show_prompt("")
	%DeckEditor.open_editor(weapon)

# 关闭所有模态表现，控制恢复仍由 Base 负责。
func hide_modals() -> void:
	%ExpeditionConfirmation.hide()
	%DeckEditor.hide()

# 保存或初始化失败时保留确认窗口，允许取消或重试。
func show_entry_failure() -> void:
	%ExpeditionConfirmation.dialog_text = "远征未启动：玩家数据或保存失败。请查看日志，修复后重试或取消。"

# 更新同一武器的现有容器显示。
func refresh_editor(weapon: WeaponInstance) -> void:
	%DeckEditor.display_weapon(weapon)

# 容量或无效请求的反馈在窗口内展示。
func show_editor_status(message: String) -> void:
	%DeckEditor.show_status(message)
