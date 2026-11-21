## 展示工作台菜单、候选及双牌组操作流程。
## 交易归会话，模态控制归远征协调器，不持有业务副本。
extends Control

const Session = preload("res://Scripts/RefCounted/CardWorkbenchSession.gd")
enum Screen { CLOSED, MAIN_MENU, DRAW_OFFER, DELETE_EDITOR, DELETE_CONFIRMATION, ADJUST_EDITOR }
signal close_requested
var screen := Screen.CLOSED
var _manager_ref: WeakRef
var _session_ref: WeakRef
var _selected_card: CardInstance
var _selected_deck: int = 0

# 稳定控件只连接一次，根节点的保存可见性不受运行时隐藏影响。
func _ready() -> void:
	hide()
	%DeckEditor.close_editor()
	%Confirmation.hide()
	%Close.pressed.connect(close_workbench)
	%Draw.pressed.connect(_on_draw)
	%Delete.pressed.connect(_open_delete)
	%Adjust.pressed.connect(_open_adjust)
	%Confirm.pressed.connect(_confirm_delete)
	%Cancel.pressed.connect(_cancel_delete)
	%DeckEditor.close_requested.connect(_back_to_menu)
	%DeckEditor.card_selected_for_deletion.connect(_on_card_selected)
	for index in 3:
		var button := %Candidates.get_child(index) as Button
		button.pressed.connect(_choose_candidate.bind(index))
		_ignore_input(button.get_node("Card"))

# 卡面保持原样，由候选位置的原生 Button 处理点击。
func _ignore_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_input(child)

# 协调器先取得模态归属，再交付当前上下文。
func open_workbench(manager: Node) -> bool:
	clear_context()
	if not is_instance_valid(manager) or not manager.is_workbench_open():
		return false
	var session: RefCounted = manager.get_workbench_session()
	if session == null or session.get_weapon_instance() == null:
		return false
	_manager_ref = weakref(manager)
	_session_ref = weakref(session)
	manager.soul_balance_changed.connect(_on_soul_changed)
	_on_soul_changed(manager.get_soul_balance())
	show()
	_set_screen(Screen.DRAW_OFFER if session.has_pending_offer() else Screen.MAIN_MENU)
	return true

# 关闭仅上报意图，协调器负责恢复原控制状态。
func close_workbench() -> void:
	if screen != Screen.CLOSED:
		close_requested.emit()

# 放弃表现引用，不清理会话或退款。
func clear_context(update_controls: bool = true) -> void:
	var manager: Node = _manager_ref.get_ref() if _manager_ref != null else null
	if is_instance_valid(manager) and manager.soul_balance_changed.is_connected(_on_soul_changed):
		manager.soul_balance_changed.disconnect(_on_soul_changed)
	_manager_ref = null
	_session_ref = null
	_selected_card = null
	screen = Screen.CLOSED
	if update_controls and is_node_ready() and is_inside_tree():
		%DeckEditor.close_editor()
		%Confirmation.hide()
		%Candidates.hide()
		%Status.text = ""
	hide()

# 销毁时也释放所有业务监听。
func _exit_tree() -> void:
	clear_context(false)

# 状态只描述当前界面，业务值每次通过原会话取得。
func _get_session() -> RefCounted:
	var manager: Node = _manager_ref.get_ref() if _manager_ref != null else null
	var session: RefCounted = _session_ref.get_ref() if _session_ref != null else null
	if not is_instance_valid(manager) or session == null or manager.get_workbench_session() != session or session.get_weapon_instance() == null:
		return null
	return session

# 协调器只查询界面绑定是否仍对应本次远征。
func has_valid_context() -> bool:
	return _get_session() != null

# 无效上下文不执行交易或继续展示成功状态。
func _require_session() -> RefCounted:
	var session := _get_session()
	if session == null:
		show_status("远征上下文已失效。")
		close_workbench()
	return session

# 单次 Esc 只执行一层导航，避免事件继续传播。
func _input(event: InputEvent) -> void:
	if not visible or (event is InputEventKey and event.echo) or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if screen == Screen.DELETE_CONFIRMATION:
		_cancel_delete()
	elif screen in [Screen.DELETE_EDITOR, Screen.ADJUST_EDITOR]:
		_back_to_menu()
	else:
		close_workbench()

# 只更新标签，不在 UI 保存第二份余额。
func _on_soul_changed(balance: int) -> void:
	%Soul.text = "Soul：%d" % balance

# 切换界面时保持原会话及待选数据。
func _set_screen(next_screen: Screen) -> void:
	screen = next_screen
	%MainMenu.visible = screen == Screen.MAIN_MENU
	%Candidates.visible = screen == Screen.DRAW_OFFER
	%DeckEditor.visible = screen in [Screen.DELETE_EDITOR, Screen.DELETE_CONFIRMATION, Screen.ADJUST_EDITOR]
	%Confirmation.visible = screen == Screen.DELETE_CONFIRMATION
	if screen == Screen.DRAW_OFFER:
		_render_offer()
	elif screen == Screen.MAIN_MENU:
		%Draw.grab_focus()

# 候选只按原索引和原模板展示，重复引用保留三个位置。
func _render_offer() -> void:
	var session := _require_session()
	if session == null:
		return
	var offer: Array[CardData] = session.get_pending_offer()
	if offer.size() != 3:
		_set_screen(Screen.MAIN_MENU)
		show_status("候选数据不可用。")
		return
	for index in 3:
		%Candidates.get_child(index).get_node("Card").display_card_data(offer[index])
	%Candidates.get_child(0).grab_focus()

# 所有费用、容量和生成判断均交给会话。
func _on_draw() -> void:
	if screen != Screen.MAIN_MENU:
		return
	var session := _require_session()
	if session == null:
		return
	var result: int = session.begin_draw()
	if _get_session() != session:
		return
	if result in [Session.Result.SUCCESS, Session.Result.OFFER_ALREADY_PENDING]:
		show_status("")
		_set_screen(Screen.DRAW_OFFER)
	else:
		show_status(_result_message(result))

# 选择失败保持原候选，不重购、不替换。
func _choose_candidate(index: int) -> void:
	if screen != Screen.DRAW_OFFER:
		return
	var session := _require_session()
	if session == null:
		return
	var result: int = session.choose_card(index)
	if _get_session() != session:
		return
	if result == Session.Result.SUCCESS:
		_set_screen(Screen.MAIN_MENU)
		show_status("卡牌已加入实战牌组。")
	else:
		show_status(_result_message(result))

# 复用既有删除选择模式，不在此执行删除。
func _open_delete() -> void:
	_open_editor(false)

# 调整沿用原编辑器和原远征武器。
func _open_adjust() -> void:
	_open_editor(true)

# 每次编辑均传入当前会话拥有的原武器。
func _open_editor(adjusting: bool) -> void:
	if screen != Screen.MAIN_MENU:
		return
	var session := _require_session()
	if session == null:
		return
	var mode: int = %DeckEditor.DisplayMode.EXPEDITION_EDIT if adjusting else %DeckEditor.DisplayMode.EXPEDITION_DELETE_SELECT
	if not %DeckEditor.setup_editor(session.get_weapon_instance(), mode, session):
		show_status("牌组编辑器上下文无效。")
		return
	show_status("")
	_set_screen(Screen.ADJUST_EDITOR if adjusting else Screen.DELETE_EDITOR)

# 确认只保留临时精确对象，不以名称或模板 ID 定位。
func _on_card_selected(card: CardInstance, deck_type: int) -> void:
	if screen != Screen.DELETE_EDITOR or _require_session() == null:
		return
	_selected_card = card
	_selected_deck = deck_type
	%ConfirmationText.text = "删除 %s（%s）？成功后返还 1 Soul。" % [card.get_card_name(), "实战牌组" if deck_type == %DeckEditor.DeckType.COMBAT else "备用牌组"]
	_set_screen(Screen.DELETE_CONFIRMATION)
	%Cancel.grab_focus()

# 取消不调用任何业务操作。
func _cancel_delete() -> void:
	if screen != Screen.DELETE_CONFIRMATION:
		return
	_selected_card = null
	_set_screen(Screen.DELETE_EDITOR)

# 确认后由会话复核对象、容器和退款原子性。
func _confirm_delete() -> void:
	if screen != Screen.DELETE_CONFIRMATION:
		return
	var session := _require_session()
	if session == null:
		return
	var result: int = session.delete_card(_selected_card, %DeckEditor.deck_id_for_type(_selected_deck))
	if _get_session() != session:
		return
	_selected_card = null
	%DeckEditor.refresh_weapon()
	_set_screen(Screen.DELETE_EDITOR)
	show_status("卡牌已删除，已返还 1 Soul。" if result == Session.Result.SUCCESS else _result_message(result))

# 关闭编辑器只返回功能菜单，不结束远征会话。
func _back_to_menu() -> void:
	if screen not in [Screen.DELETE_EDITOR, Screen.ADJUST_EDITOR]:
		return
	_selected_card = null
	%DeckEditor.close_editor()
	_set_screen(Screen.MAIN_MENU)
	show_status("")

# 错误描述只映射真实业务结果，不推断成功。
func _result_message(result: int) -> String:
	match result:
		Session.Result.INSUFFICIENT_SOUL: return "Soul 不足，抽卡需要 3 Soul。"
		Session.Result.COMBAT_DECK_FULL: return "实战牌组已满，请先移出或删除卡牌。"
		Session.Result.EMPTY_CARD_POOL: return "卡池为空或候选生成失败。"
		Session.Result.INVALID_SELECTION: return "候选选择无效。"
		Session.Result.CARD_CREATION_FAILED: return "卡牌模板无效，无法创建卡牌。"
		Session.Result.CARD_INSERTION_FAILED: return "卡牌加入失败，原候选已保留。"
		Session.Result.INVALID_CARD: return "删除目标已失效，请重新选择。"
		Session.Result.REFUND_FAILED: return "删除失败：无法安全返还 Soul。"
		Session.Result.OPERATION_IN_PROGRESS: return "操作正在处理中。"
	return "远征上下文或操作状态无效。"

# 状态反馈保持简单控件文本。
func show_status(message: String) -> void:
	%Status.text = message
