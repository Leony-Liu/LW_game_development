## 将协调器提供的显示快照渲染为玩家、敌人和调试文本。
## 只依赖本场景控件，不查询玩法系统或保存战斗状态。
class_name CombatHUD
extends Control

@export var player_info_label: Label
@export var enemy_info_container: VBoxContainer
@export var future_actions_label: Label
@export var debug_status_label: Label

# 校验编辑器配置，未接收快照时保留场景占位文本。
func _ready() -> void:
	validate_configuration()


# 校验必需控件；失败时阻止协调器继续依赖此 HUD。
func validate_configuration() -> bool:
	if player_info_label == null or enemy_info_container == null:
		push_error("CombatHUD: 缺少 player_info_label 或 enemy_info_container 引用。")
		return false
	if future_actions_label == null or debug_status_label == null:
		push_error("CombatHUD: 缺少 future_actions_label 或 debug_status_label 引用。")
		return false
	return true


# 立即显示值快照，不保留模型或节点引用。
func display_state(snapshot: Dictionary) -> void:
	if not validate_configuration():
		return
	if not snapshot.has_all(["player", "enemies", "piles", "current_time", "future_actions", "scheduled_actions", "input_allowed", "is_advancing", "has_pending_action", "battle_ended"]):
		push_error("CombatHUD: 显示快照缺少必需字段。")
		return
	player_info_label.text = _build_player_text(snapshot.player, snapshot.piles, snapshot.current_time)
	_refresh_enemy_info(snapshot.enemies, snapshot.scheduled_actions)
	future_actions_label.text = _build_future_actions_text(snapshot.future_actions)
	debug_status_label.text = _build_debug_text(snapshot)


# 构建玩家属性、牌堆与时间文本。
func _build_player_text(player: Dictionary, piles: Dictionary, current_time: int) -> String:
	if player.is_empty():
		return "玩家状态\n等待 Battle 初始化"
	return "玩家状态\nHP: %s / %s\n体力: %s / %s\n法力: %s / %s\n手牌: %d / %d\n抽牌堆: %d\n弃牌堆: %d\n当前时间: %d" % [
		_format_number(player.hp),
		_format_number(player.max_hp),
		_format_number(player.stamina),
		_format_number(player.max_stamina),
		_format_number(player.mana),
		_format_number(player.max_mana),
		piles.hand,
		piles.limit,
		piles.draw,
		piles.discard,
		current_time,
	]


# 用独立纵向信息块刷新全部当前敌人。
func _refresh_enemy_info(enemies: Array, scheduled_actions: Array) -> void:
	for child in enemy_info_container.get_children():
		enemy_info_container.remove_child(child)
		child.queue_free()

	var heading := Label.new()
	heading.text = "敌人状态"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_font_size_override("font_size", 17)
	enemy_info_container.add_child(heading)

	if enemies.is_empty():
		var empty_label := Label.new()
		empty_label.text = "无当前敌人"
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_info_container.add_child(empty_label)
		return

	for index in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		var identifier: String = enemy.entity_id

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
		_add_enemy_row(enemy_block, "HP", "%s / %s" % [_format_number(enemy.hp), _format_number(enemy.max_hp)])
		_add_enemy_row(enemy_block, "下次行动", _get_next_action_time_text(identifier, scheduled_actions))

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
func _build_future_actions_text(snapshots: Array) -> String:
	var lines: PackedStringArray = ["未来 100 时间单位 · 敌方行动"]
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
func _build_debug_text(snapshot: Dictionary) -> String:
	return "调试状态\n玩家输入: %s\nTimeline 推进: %s\n待确认行动: %s\nBattle 结束: %s" % [
		"允许" if snapshot.input_allowed else "锁定",
		"是" if snapshot.is_advancing else "否",
		"是" if snapshot.has_pending_action else "否",
		"是" if snapshot.battle_ended else "否",
	]


# 返回指定敌人的下一项已排期行动时间。
func _get_next_action_time_text(entity_id: String, scheduled_actions: Array) -> String:
	for snapshot in scheduled_actions:
		if snapshot.source_id == entity_id:
			return "T=%d (+%d)" % [snapshot.trigger_time, snapshot.relative_time]
	return "无"


# 统一整数与小数显示。
func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value
