## 以文本方式呈现当前 Battle、实体、牌堆与 Timeline 的只读状态。
## 仅监听 gameplay 信号并刷新标签，不持有或修改战斗真相。
class_name CombatHUD
extends Control

@export var battle_manager: BattleManager
@export var timeline: Timeline
@export var entity_manager: EntityManager
@export var card_manager: CardManager

@export var player_info_label: Label
@export var enemy_info_container: VBoxContainer
@export var future_actions_label: Label
@export var debug_status_label: Label

var _battle_has_ended: bool = false
var _refresh_queued: bool = false


# 校验引用、连接状态信号并完成首次显示。
func _ready() -> void:
	_validate_dependencies()
	_connect_refresh_signals()
	_bind_entity_signals()
	refresh()


# 校验 HUD 的只读数据源与标签引用。
func _validate_dependencies() -> void:
	assert(battle_manager != null, "CombatHUD: 缺少 battle_manager 引用。")
	assert(timeline != null, "CombatHUD: 缺少 timeline 引用。")
	assert(entity_manager != null, "CombatHUD: 缺少 entity_manager 引用。")
	assert(card_manager != null, "CombatHUD: 缺少 card_manager 引用。")
	assert(player_info_label != null, "CombatHUD: 缺少 player_info_label 引用。")
	assert(enemy_info_container != null, "CombatHUD: 缺少 enemy_info_container 引用。")
	assert(future_actions_label != null, "CombatHUD: 缺少 future_actions_label 引用。")
	assert(debug_status_label != null, "CombatHUD: 缺少 debug_status_label 引用。")


# 连接会改变 HUD 内容的现有 gameplay 信号。
func _connect_refresh_signals() -> void:
	battle_manager.battle_started.connect(_on_battle_started)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.input_lock_changed.connect(_on_input_lock_changed)
	timeline.timeline_data_updated.connect(_on_timeline_data_updated)
	timeline.pending_action_changed.connect(_on_pending_action_changed)
	card_manager.deck_initialized.connect(_on_deck_initialized)
	card_manager.card_drawn.connect(_on_card_changed)
	card_manager.card_played.connect(_on_card_changed)
	card_manager.card_discarded.connect(_on_card_changed)
	card_manager.discard_shuffled_into_draw.connect(_on_discard_shuffled)
	card_manager.hand_pile_cleared.connect(_queue_refresh)


# 连接当前玩家与全部敌人的属性变化信号。
func _bind_entity_signals() -> void:
	var entities: Array[CombatEntity] = []
	if entity_manager.player_entity != null:
		entities.append(entity_manager.player_entity)
	entities.append_array(entity_manager.get_enemy_entities())
	for entity in entities:
		if entity.attribute_set == null:
			continue
		var callback := Callable(self, "_on_attribute_updated")
		if not entity.attribute_set.attribute_updated.is_connected(callback):
			entity.attribute_set.attribute_updated.connect(callback)


# 刷新全部文本，不修改任何数据源。
func refresh() -> void:
	_refresh_queued = false
	player_info_label.text = _build_player_text()
	_refresh_enemy_info()
	future_actions_label.text = _build_future_actions_text()
	debug_status_label.text = _build_debug_text()


# 合并同一帧内的多次状态变化，避免重复构建文本。
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	refresh.call_deferred()


# 构建玩家属性、牌堆与时间文本。
func _build_player_text() -> String:
	var player := entity_manager.player_entity
	if player == null or player.attribute_set == null:
		return "玩家状态\n等待 Battle 初始化"
	var attributes := player.attribute_set
	return "玩家状态\nHP: %s / %s\n体力: %s / %s\n法力: %s / %s\n手牌: %d / %d\n抽牌堆: %d\n弃牌堆: %d\n当前时间: %d" % [
		_format_number(attributes.get_value("hp")),
		_format_number(_get_max_value(attributes, "hp")),
		_format_number(attributes.get_value("stamina")),
		_format_number(_get_max_value(attributes, "stamina")),
		_format_number(attributes.get_value("mana")),
		_format_number(_get_max_value(attributes, "mana")),
		card_manager.hand_pile.size(),
		card_manager.hand_limit,
		card_manager.draw_pile.size(),
		card_manager.discard_pile.size(),
		timeline.current_time,
	]


# 用独立纵向信息块刷新全部当前敌人。
func _refresh_enemy_info() -> void:
	for child in enemy_info_container.get_children():
		enemy_info_container.remove_child(child)
		child.queue_free()

	var heading := Label.new()
	heading.text = "敌人状态"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_font_size_override("font_size", 17)
	enemy_info_container.add_child(heading)

	var enemies := entity_manager.get_enemy_entities()
	if enemies.is_empty():
		var empty_label := Label.new()
		empty_label.text = "无当前敌人"
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_info_container.add_child(empty_label)
		return

	for index in range(enemies.size()):
		var enemy := enemies[index]
		var identifier: String = enemy.entity_id if not enemy.entity_id.is_empty() else String(enemy.name)
		var hp := 0.0
		var max_hp := 0.0
		if enemy.attribute_set != null:
			hp = enemy.attribute_set.get_value("hp")
			max_hp = _get_max_value(enemy.attribute_set, "hp")

		var enemy_block := VBoxContainer.new()
		enemy_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_block.add_theme_constant_override("separation", 2)
		enemy_info_container.add_child(enemy_block)
		var title := Label.new()
		title.text = "敌人 %d" % (index + 1)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_theme_font_size_override("font_size", 16)
		enemy_block.add_child(title)
		_add_enemy_row(enemy_block, "Entity ID", identifier)
		_add_enemy_row(enemy_block, "名称", String(enemy.name))
		_add_enemy_row(enemy_block, "HP", "%s / %s" % [_format_number(hp), _format_number(max_hp)])
		_add_enemy_row(enemy_block, "下次行动", _get_next_action_time_text(identifier))

		if index < enemies.size() - 1:
			var separator := HSeparator.new()
			separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
			enemy_info_container.add_child(separator)


# 创建不溢出面板的单行键值展示。
func _add_enemy_row(parent: VBoxContainer, key: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var key_label := Label.new()
	key_label.custom_minimum_size.x = 92.0
	key_label.text = key + ":"
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(key_label)
	var value_label := Label.new()
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.text = value
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value_label)


# 构建未来 100 时间单位内的已知敌方行动列表。
func _build_future_actions_text() -> String:
	var lines: PackedStringArray = ["未来 100 时间单位 · 敌方行动"]
	var snapshots := timeline.get_scheduled_enemy_action_snapshots(100)
	if snapshots.is_empty():
		lines.append("暂无已排期行动")
		return "\n".join(lines)
	for snapshot in snapshots:
		lines.append("+%d  T=%d  %s  %s" % [
			snapshot.relative_time,
			snapshot.trigger_time,
			snapshot.source_id,
			snapshot.action_name,
		])
	return "\n".join(lines)


# 构建输入锁、推进、待确认与 Battle 生命周期文本。
func _build_debug_text() -> String:
	var input_allowed := battle_manager.is_battle_active and not battle_manager.is_battle_input_locked()
	return "调试状态\n玩家输入: %s\nTimeline 推进: %s\n待确认行动: %s\nBattle 结束: %s" % [
		"允许" if input_allowed else "锁定",
		"是" if timeline.is_advancing else "否",
		"是" if timeline.has_pending_action() else "否",
		"是" if _battle_has_ended else "否",
	]


# 读取显式最大属性；缺失时使用该属性的初始化值。
func _get_max_value(attributes: AttributeSet, attribute_name: String) -> float:
	var max_attribute_name := "max_%s" % attribute_name
	if attributes.get_attribute(max_attribute_name) != null:
		return attributes.get_value(max_attribute_name)
	return attributes.get_initial_value(attribute_name)


# 返回指定敌人的下一项已排期行动时间。
func _get_next_action_time_text(entity_id: String) -> String:
	for snapshot in timeline.get_scheduled_enemy_action_snapshots(1000000):
		if snapshot.source_id == entity_id:
			return "T=%d (+%d)" % [snapshot.trigger_time, snapshot.relative_time]
	return "无"


# 统一整数与小数显示。
func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value


# Battle 初始化后重新绑定实体并刷新。
func _on_battle_started() -> void:
	_battle_has_ended = false
	_bind_entity_signals()
	_queue_refresh()


# Battle 结束时保留最终数值并更新状态标记。
func _on_battle_ended(_is_player_victory: bool) -> void:
	_battle_has_ended = true
	_queue_refresh()


# 属性变化只触发合并刷新。
func _on_attribute_updated(_attribute_name: String, _old_value: float, _new_value: float) -> void:
	_queue_refresh()


# 输入锁变化只触发合并刷新。
func _on_input_lock_changed(_is_locked: bool) -> void:
	_queue_refresh()


# Timeline 数据变化只触发合并刷新。
func _on_timeline_data_updated(_current_time: int, _action_line: Array[CombatAction]) -> void:
	_queue_refresh()


# 待确认状态变化只触发合并刷新。
func _on_pending_action_changed(_is_pending: bool) -> void:
	_queue_refresh()


# 牌组初始化只触发合并刷新。
func _on_deck_initialized(_deck_size: int) -> void:
	_queue_refresh()


# 单张卡牌流转只触发合并刷新。
func _on_card_changed(_runtime_card: RuntimeCard) -> void:
	_queue_refresh()


# 弃牌堆洗回只触发合并刷新。
func _on_discard_shuffled(_shuffled_amount: int) -> void:
	_queue_refresh()
