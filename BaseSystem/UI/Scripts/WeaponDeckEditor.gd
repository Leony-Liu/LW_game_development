## 共用武器双牌组编辑与实战牌组只读呈现。
## 只接收拥有者提供的数据，不访问存档或执行牌组变更。
extends Control

signal close_requested
signal transfer_requested(source_id: String, uid: String)

enum DisplayMode { EDIT, COMBAT_VIEW }
var display_mode: DisplayMode = DisplayMode.EDIT

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
	_begin_session(DisplayMode.EDIT)
	display_weapon(weapon)
	visible = true
	%CloseButton.grab_focus()

# 只呈现传入的原实战卡牌引用，不接收备用牌组或武器所有权。
func open_combat_view(combat_cards: Array[CardInstance]) -> void:
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
	%CombatScroll.set_interaction_enabled(mode == DisplayMode.EDIT)
	%ReserveScroll.set_interaction_enabled(mode == DisplayMode.EDIT)
	%ReservePanel.visible = mode == DisplayMode.EDIT
	$Window/Content/Help.text = _edit_help_text if mode == DisplayMode.EDIT else "只读查看实战牌组；滚轮或滚动条浏览；Tab / Esc 关闭"
	%CombatScroll.scroll_vertical = 0
	%ReserveScroll.scroll_horizontal = 0

# 关闭时移除临时卡片并恢复可预测的编辑默认状态。
func close_editor() -> void:
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
	if display_mode != DisplayMode.EDIT:
		return
	_clear_cards(%CombatGrid)
	_clear_cards(%ReserveRow)
	if weapon == null:
		%WeaponName.text = "尚未配置玩家武器"
		%CombatCount.text = "实战牌组 0/20"
		%ReserveCount.text = "备用牌组 0"
		show_status("没有可编辑的武器；不会创建替代武器或起始牌组。")
		return
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
		view.set_interaction_enabled(display_mode == DisplayMode.EDIT)
		view.display_card(card, source_id, session_id)
		view.transfer_requested.connect(_on_transfer_requested.bind(session_id))
		view.card_dropped.connect(_on_card_dropped)
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
	if display_mode == DisplayMode.EDIT:
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
	if display_mode != DisplayMode.EDIT or not visible or data.get("session_id") != session_id or data.get("kind") != "weapon_deck_card":
		return
	var source_id: String = data.get("source_id", "")
	if source_id not in ["combat_deck", "reserve_deck"] or destination_id not in ["combat_deck", "reserve_deck"] or source_id == destination_id or not data.get("card_uid") is String:
		return
	transfer_requested.emit(source_id, data["card_uid"])

# 右键意图也必须经过模式门闩，不能绕过只读限制。
func _on_transfer_requested(source_id: String, uid: String, request_session: int) -> void:
	if visible and display_mode == DisplayMode.EDIT and request_session == session_id:
		transfer_requested.emit(source_id, uid)

# 动态卡片退出场景后延迟释放，避免中断当前拖放回调。
func _clear_cards(layout: Container) -> void:
	for child in layout.get_children():
		layout.remove_child(child)
		child.queue_free()
