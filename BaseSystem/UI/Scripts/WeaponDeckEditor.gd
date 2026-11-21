## 共用武器双牌组编辑与实战牌组只读呈现。
## 接收明确上下文，远征复用容器转移，删除仅上报选择；不访问存档。
extends Control

signal close_requested
signal transfer_requested(source_id: String, uid: String)

enum DisplayMode { EDIT, COMBAT_VIEW, EXPEDITION_EDIT, EXPEDITION_DELETE_SELECT }
enum DeckType { COMBAT, RESERVE }
signal card_selected_for_deletion(card_instance: CardInstance, deck_type: DeckType)
var display_mode: DisplayMode = DisplayMode.EDIT
var _weapon_ref: WeakRef
var _workbench_ref: WeakRef
var _displayed_combat: Array[CardInstance] = []
var _displayed_reserve: Array[CardInstance] = []

@export_group("Card Content")
@export var card_scene: PackedScene
@export_group("Card Layout")
@export_range(0.1, 1.5, 0.05) var preferred_card_scale: float = 1.0:
	set(value):
		preferred_card_scale = value
		if is_node_ready():
			_queue_card_layout()
var session_id: int = 0
@onready var _edit_help_text: String = $Window/Content/Help.text

# 连接稳定场景布局中的控件。
func _ready() -> void:
	%CloseButton.pressed.connect(close_requested.emit)
	%CombatScroll.card_dropped.connect(_on_card_dropped)
	%ReserveScroll.card_dropped.connect(_on_card_dropped)
	%CombatScroll.resized.connect(_queue_card_layout)
	%ReserveScroll.resized.connect(_queue_card_layout)
	%ReserveCount.minimum_size_changed.connect(_queue_card_layout)

# 每次打开建立新拖拽会话，不生成武器或卡牌。
func open_editor(weapon: WeaponInstance) -> void:
	open_for_edit(weapon)

# 保留原双牌组布局与交互，每次打开建立独立会话。
func open_for_edit(weapon: WeaponInstance) -> void:
	_release_context()
	_begin_session(DisplayMode.EDIT)
	display_weapon(weapon)
	visible = true
	%CloseButton.grab_focus()

# 远征上下文必须匹配原会话，防止错误来源或结束后继续编辑。
func setup_editor(weapon: WeaponInstance, mode: DisplayMode, workbench_session: RefCounted = null) -> bool:
	close_editor()
	if weapon == null or weapon.combat_deck == null or weapon.reserve_deck == null or card_scene == null or mode == DisplayMode.COMBAT_VIEW:
		push_error("[WeaponDeckEditor] 打开失败：武器或编辑模式无效。")
		return false
	if mode not in [DisplayMode.EDIT, DisplayMode.EXPEDITION_EDIT, DisplayMode.EXPEDITION_DELETE_SELECT]:
		return false
	if mode != DisplayMode.EDIT:
		if workbench_session == null or not workbench_session.has_method("get_weapon_instance") or not workbench_session.has_signal("card_added") or not workbench_session.has_signal("card_removed") or workbench_session.get_weapon_instance() != weapon:
			push_error("[WeaponDeckEditor] 打开失败：远征武器与工作台会话不匹配。")
			return false
		_workbench_ref = weakref(workbench_session)
		workbench_session.card_added.connect(_on_session_card_added)
		workbench_session.card_removed.connect(_on_session_card_removed)
	_begin_session(mode)
	display_weapon(weapon)
	show()
	%CloseButton.grab_focus()
	return true

# 返回当前明确注入的原武器，不创建副本或回退到 Base。
func get_weapon_instance() -> WeaponInstance:
	return _weapon_ref.get_ref() as WeaponInstance if _weapon_ref != null else null

# 外部业务操作后可主动刷新，数据始终从容器重新读取。
func refresh_weapon() -> void:
	if display_mode == DisplayMode.COMBAT_VIEW:
		return
	if _is_expedition_mode() and not _is_expedition_context_valid():
		close_editor()
		return
	var weapon := get_weapon_instance()
	if weapon != null:
		display_weapon(weapon)

# 监测会话清理和外部容器转移，只缓存显示快照作比较。
func _process(_delta: float) -> void:
	if not visible or not _is_expedition_mode():
		return
	if not _is_expedition_context_valid():
		close_editor()
		return
	var weapon := get_weapon_instance()
	if weapon.combat_deck.get_cards() != _displayed_combat or weapon.reserve_deck.get_cards() != _displayed_reserve:
		refresh_weapon()

# 远征两种模式共享会话有效性门闩。
func _is_expedition_mode() -> bool:
	return display_mode in [DisplayMode.EXPEDITION_EDIT, DisplayMode.EXPEDITION_DELETE_SELECT]

# 弱引用不延长远征数据寿命，操作入口同步验证结束状态。
func _is_expedition_context_valid() -> bool:
	var session: RefCounted = _workbench_ref.get_ref() if _workbench_ref != null else null
	var weapon := get_weapon_instance()
	return session != null and weapon != null and session.get_weapon_instance() == weapon and weapon.combat_deck != null and weapon.reserve_deck != null

# 断开旧业务监听并丢弃显示上下文。
func _release_context() -> void:
	var session: RefCounted = _workbench_ref.get_ref() if _workbench_ref != null else null
	if session != null:
		if session.card_added.is_connected(_on_session_card_added):
			session.card_added.disconnect(_on_session_card_added)
		if session.card_removed.is_connected(_on_session_card_removed):
			session.card_removed.disconnect(_on_session_card_removed)
	_workbench_ref = null
	_weapon_ref = null
	_displayed_combat.clear()
	_displayed_reserve.clear()

# 会话只通知已完成的业务，编辑器重新读取原容器。
func _on_session_card_added(_card: CardInstance) -> void:
	refresh_weapon()

# 删牌确认仍由未来工作台拥有者负责。
func _on_session_card_removed(_card: CardInstance, _deck_type: String) -> void:
	refresh_weapon()

# 编辑器释放时不留下会话监听。
func _exit_tree() -> void:
	_release_context()

# 与 CardWorkbenchSession 的既有容器标识对接。
static func deck_id_for_type(deck_type: DeckType) -> String:
	return "combat_deck" if deck_type == DeckType.COMBAT else "reserve_deck"

# 只呈现传入的原实战卡牌引用，不接收备用牌组或武器所有权。
func open_combat_view(combat_cards: Array[CardInstance]) -> void:
	_release_context()
	_begin_session(DisplayMode.COMBAT_VIEW)
	_clear_cards(%CombatGrid)
	_clear_cards(%ReserveRow)
	%WeaponName.text = "实战牌组（只读）"
	%CombatCount.text = "实战牌组 %d" % combat_cards.size()
	%ReserveCount.text = "备用牌组 0"
	var missing_count := _populate_cards(combat_cards, %CombatGrid, "combat_deck")
	show_status("实战牌组为空。" if combat_cards.is_empty() else "")
	_show_missing_templates(missing_count)
	visible = true
	_queue_card_layout()
	%CloseButton.grab_focus()

# 在填充前设置模式，并使旧拖放载荷失效。
func _begin_session(mode: DisplayMode) -> void:
	display_mode = mode
	session_id += 1
	%CombatScroll.session_id = session_id
	%ReserveScroll.session_id = session_id
	var editing := mode in [DisplayMode.EDIT, DisplayMode.EXPEDITION_EDIT]
	%CombatScroll.set_interaction_enabled(editing)
	%ReserveScroll.set_interaction_enabled(editing)
	%ReservePanel.visible = mode != DisplayMode.COMBAT_VIEW
	$Window/Content/Help.text = _edit_help_text if editing else ("点击卡牌选择删除；确认由工作台处理" if mode == DisplayMode.EXPEDITION_DELETE_SELECT else "只读查看实战牌组；滚轮或滚动条浏览；Tab / Esc 关闭")
	%CombatScroll.scroll_vertical = 0
	%ReserveScroll.scroll_horizontal = 0

# 关闭时移除临时卡片并恢复可预测的编辑默认状态。
func close_editor() -> void:
	_release_context()
	hide()
	_clear_cards(%CombatGrid)
	_clear_cards(%ReserveRow)
	_begin_session(DisplayMode.EDIT)
	%WeaponName.text = "武器牌组"
	%CombatCount.text = "实战牌组 0/20"
	%ReserveCount.text = "备用牌组 0"
	show_status("")

# 按模型当前顺序重建动态卡片，模板缺失仍保留真实实例位置。
func display_weapon(weapon: WeaponInstance) -> void:
	if display_mode == DisplayMode.COMBAT_VIEW:
		return
	if _is_expedition_mode() and (not _is_expedition_context_valid() and _weapon_ref != null):
		close_editor()
		return
	if _is_expedition_mode():
		var session: RefCounted = _workbench_ref.get_ref() if _workbench_ref != null else null
		if session == null or session.get_weapon_instance() != weapon:
			close_editor()
			return
	_weapon_ref = weakref(weapon) if weapon != null else null
	_clear_cards(%CombatGrid)
	_clear_cards(%ReserveRow)
	if weapon == null:
		%WeaponName.text = "尚未配置玩家武器"
		%CombatCount.text = "实战牌组 0/20"
		%ReserveCount.text = "备用牌组 0"
		show_status("没有可编辑的武器；不会创建替代武器或起始牌组。")
		return
	_displayed_combat = weapon.combat_deck.get_cards()
	_displayed_reserve = weapon.reserve_deck.get_cards()
	%WeaponName.text = weapon.weapon_data.name if weapon.weapon_data != null else "武器模板不可用（ID %d）" % weapon.weapon_id
	%CombatCount.text = "实战牌组 %d/%d" % [weapon.combat_deck.get_cards().size(), weapon.combat_deck.capacity]
	%ReserveCount.text = "备用牌组 %d" % weapon.reserve_deck.get_cards().size()
	show_status("")
	var missing_count := 0
	for container in [weapon.combat_deck, weapon.reserve_deck]:
		var layout: Container = %CombatGrid if container == weapon.combat_deck else %ReserveRow
		missing_count += _populate_cards(container.get_cards(), layout, container.container_id)
	_queue_card_layout()
	_show_missing_templates(missing_count)

# 两种模式共用同一动态卡片工厂和卡面实现。
func _populate_cards(cards: Array[CardInstance], layout: Container, source_id: String) -> int:
	var missing_count := 0
	for card in cards:
		var view := card_scene.instantiate()
		layout.add_child(view)
		view.set_interaction_enabled(display_mode in [DisplayMode.EDIT, DisplayMode.EXPEDITION_EDIT])
		view.set_selection_enabled(display_mode == DisplayMode.EXPEDITION_DELETE_SELECT)
		view.display_card(card, source_id, session_id)
		view.transfer_requested.connect(_on_transfer_requested.bind(session_id))
		view.card_dropped.connect(_on_card_dropped)
		view.selection_requested.connect(_on_card_selected)
		if card.card_data == null:
			missing_count += 1
	return missing_count

# 缺模板仍保留原实例的展示位置。
func _show_missing_templates(missing_count: int) -> void:
	if missing_count > 0:
		show_status("%d 张卡牌缺少模板数据；原实例与位置保留。" % missing_count)
		push_warning("[WeaponDeckEditor] %d 张卡牌模板不可用；未生成替代卡牌。" % missing_count)

# 等待原生容器完成布局，再按实际可用区域缩放。
func _queue_card_layout() -> void:
	_update_card_layout.call_deferred()

# 优先采用 Inspector 比例，空间不足时两区统一缩小，保留原生滚动。
func _update_card_layout() -> void:
	if %CombatGrid.get_child_count() + %ReserveRow.get_child_count() == 0:
		return
	var views: Array[Node] = %CombatGrid.get_children() + %ReserveRow.get_children()
	var template_size: Vector2 = views[0].get_node("%CardView").custom_minimum_size
	var reserve_height: float = %ReserveScroll.size.y - %ReserveScroll.get_h_scroll_bar().get_combined_minimum_size().y
	var card_scale := preferred_card_scale
	if display_mode != DisplayMode.COMBAT_VIEW:
		card_scale = minf(card_scale, maxf(1.0, reserve_height) / template_size.y)
	var columns: int = maxi(1, %CombatGrid.columns)
	var grid_gaps: float = %CombatGrid.get_theme_constant("h_separation") * (columns - 1)
	var combat_insets: float = %CombatPadding.get_theme_constant("margin_left") + %CombatPadding.get_theme_constant("margin_right")
	var available_width: float = %CombatScroll.size.x - combat_insets - %CombatScroll.get_v_scroll_bar().get_combined_minimum_size().x
	card_scale = minf(card_scale, maxf(1.0, available_width - grid_gaps) / (template_size.x * columns))
	for view in views:
		view.set_card_scale(card_scale)

# 只显示操作结果，不修改玩法数据。
func show_status(message: String) -> void:
	%Status.text = message

# 拒绝其他窗口或旧会话的拖放，再向 Base 上报原实例身份。
func _on_card_dropped(data: Dictionary, destination_id: String) -> void:
	if display_mode not in [DisplayMode.EDIT, DisplayMode.EXPEDITION_EDIT] or not visible or data.get("session_id") != session_id or data.get("kind") != "weapon_deck_card":
		return
	var source_id: String = data.get("source_id", "")
	if source_id not in ["combat_deck", "reserve_deck"] or destination_id not in ["combat_deck", "reserve_deck"] or source_id == destination_id or not data.get("card_uid") is String:
		return
	_on_transfer_requested(source_id, data["card_uid"], session_id)

# 右键意图也必须经过模式门闩，不能绕过只读限制。
func _on_transfer_requested(source_id: String, uid: String, request_session: int) -> void:
	if not visible or request_session != session_id:
		return
	if display_mode == DisplayMode.EDIT:
		transfer_requested.emit(source_id, uid)
	elif display_mode == DisplayMode.EXPEDITION_EDIT and _is_expedition_context_valid():
		var weapon := get_weapon_instance()
		if source_id not in ["combat_deck", "reserve_deck"]:
			return
		var source := weapon.combat_deck if source_id == "combat_deck" else weapon.reserve_deck
		var destination := weapon.reserve_deck if source == weapon.combat_deck else weapon.combat_deck
		# 与 Base 共用 CardContainer 的原子转移及容量校验，不新增调整算法。
		if not source.transfer_to(destination, uid):
			show_status("移动失败；请检查源卡牌及实战牌组容量。")
			return
		refresh_weapon()

# 删除模式只解析原实例并上报，不移除卡牌或操作 Soul。
func _on_card_selected(source_id: String, uid: String, request_session: int) -> void:
	if not visible or display_mode != DisplayMode.EXPEDITION_DELETE_SELECT or request_session != session_id or not _is_expedition_context_valid():
		return
	if source_id not in ["combat_deck", "reserve_deck"]:
		return
	var weapon := get_weapon_instance()
	var container := weapon.combat_deck if source_id == "combat_deck" else weapon.reserve_deck
	var card := container.find_card(uid)
	if card != null and card.container_ref != null and card.container_ref.get_ref() == container:
		card_selected_for_deletion.emit(card, DeckType.COMBAT if source_id == "combat_deck" else DeckType.RESERVE)

# 动态卡片退出场景后延迟释放，避免中断当前拖放回调。
func _clear_cards(layout: Container) -> void:
	for child in layout.get_children():
		layout.remove_child(child)
		child.queue_free()
