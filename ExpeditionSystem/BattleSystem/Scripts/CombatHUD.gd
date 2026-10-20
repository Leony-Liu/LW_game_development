## 将 BattleManager 的显示快照绘制为战斗界面。
## 只更新本场景控件，不持有玩法状态或查询其他系统。
class_name CombatHUD
extends Control

@export var player_hp_label: Label
@export var resource_values_label: Label
@export var stamina_pips: Control
@export var mana_pips: Control
@export var enemy_hp_bar: ProgressBar
@export var enemy_hp_label: Label
@export var intent_row: HBoxContainer
@export var intent_template: Panel
@export var draw_button: Button
@export var discard_button: Button
@export var advance_button: Button
@export var intent_tooltip: PanelContainer
@export var intent_tooltip_label: Label
@export_range(1.0, 1.3, 0.01) var intent_preview_scale: float = 1.12
@export_range(0.0, 0.3, 0.01) var intent_preview_duration: float = 0.12

signal draw_requested
signal discard_mode_toggle_requested
signal advance_requested

var _input_allowed: bool = false
var _discard_mode_active: bool = false
var _hovered_intent: Panel = null
var _hovered_action_id: int = -1
var _mouse_viewport_position: Vector2 = Vector2.INF
var _last_mouse_position: Vector2 = Vector2.INF
var _preview_action_ids: Array[int] = []

# 校验场景引用，未收到快照时显示编辑器占位值。
func _ready() -> void:
	if not validate_configuration():
		return
	draw_button.pressed.connect(draw_requested.emit)
	discard_button.pressed.connect(discard_mode_toggle_requested.emit)
	advance_button.pressed.connect(advance_requested.emit)
	intent_tooltip.resized.connect(_position_intent_tooltip)
	visibility_changed.connect(_on_hud_visibility_changed)
	set_process(false)
	_update_buttons()


# 必需控件缺失时阻止依赖此界面继续启动。
func validate_configuration() -> bool:
	if player_hp_label == null or resource_values_label == null or stamina_pips == null or mana_pips == null:
		push_error("[CombatHUD] 玩家状态控件引用缺失。")
		return false
	if enemy_hp_bar == null or enemy_hp_label == null:
		push_error("[CombatHUD] 敌人血量控件引用缺失。")
		return false
	if intent_row == null or intent_template == null:
		push_error("[CombatHUD] 敌方行动图标控件引用缺失。")
		return false
	if draw_button == null or discard_button == null or advance_button == null:
		push_error("[CombatHUD] 战斗按钮引用缺失。")
		return false
	if intent_tooltip == null or intent_tooltip_label == null:
		push_error("[CombatHUD] 敌方行动提示框引用缺失。")
		return false
	return true


# 读取快照显示值，仅在行动图标节点保留对应的显示字段。
func display_state(snapshot: Dictionary) -> void:
	if not validate_configuration():
		return
	if not snapshot.has_all(["player", "enemies", "piles", "current_time", "future_actions", "preview_action_ids", "scheduled_actions", "input_allowed", "is_advancing", "has_pending_action", "battle_ended"]):
		push_error("[CombatHUD] 显示快照缺少必需字段。")
		return
	var player: Dictionary = snapshot.player
	var enemies: Array = snapshot.enemies
	_input_allowed = bool(snapshot.input_allowed)
	_update_buttons()
	if bool(snapshot.battle_ended):
		hide_intent_tooltip()
	if player.is_empty():
		player_hp_label.text = "—"
		resource_values_label.text = "体力 —  ·  法力 —"
		_set_pips(stamina_pips, 0.0, 1.0)
		_set_pips(mana_pips, 0.0, 1.0)
	else:
		player_hp_label.text = "%s/%s" % [_format_number(player.hp), _format_number(player.max_hp)]
		resource_values_label.text = "体力 %s/%s  ·  法力 %s/%s" % [
			_format_number(player.stamina), _format_number(player.max_stamina),
			_format_number(player.mana), _format_number(player.max_mana),
		]
		_set_pips(stamina_pips, float(player.stamina), float(player.max_stamina))
		_set_pips(mana_pips, float(player.mana), float(player.max_mana))
	if enemies.is_empty():
		enemy_hp_label.text = "—/—"
		enemy_hp_bar.max_value = 1.0
		enemy_hp_bar.value = 0.0
	else:
		var enemy: Dictionary = enemies[0]
		enemy_hp_label.text = "%s/%s" % [_format_number(enemy.hp), _format_number(enemy.max_hp)]
		enemy_hp_bar.max_value = maxf(float(enemy.max_hp), 1.0)
		enemy_hp_bar.value = clampf(float(enemy.hp), 0.0, enemy_hp_bar.max_value)
	_refresh_intents(snapshot.future_actions, enemies)
	_set_intent_preview(snapshot.preview_action_ids)


# 只保存按钮的呈现状态；弃牌模式由手牌视图持有。
func set_discard_mode(active: bool) -> void:
	_discard_mode_active = active
	if active:
		clear_intent_preview()
	_update_buttons()


# 弃牌模式期间只保留弃牌按钮可用。
func _update_buttons() -> void:
	if draw_button == null or discard_button == null or advance_button == null:
		return
	draw_button.disabled = not _input_allowed or _discard_mode_active
	discard_button.disabled = not _input_allowed
	advance_button.disabled = not _input_allowed or _discard_mode_active


# 仅显示血条对应敌人在现有未来窗口内的行动，并保留每个行动实例的身份。
func _refresh_intents(future_actions: Array, enemies: Array) -> void:
	var visible_actions: Array[Dictionary] = []
	if not enemies.is_empty():
		var enemy: Dictionary = enemies[0]
		if float(enemy.hp) > 0.0:
			for entry in future_actions:
				if entry is Dictionary and entry.get("source_id", "") == enemy.entity_id:
					visible_actions.append(entry)
	var existing: Dictionary = {}
	for child in intent_row.get_children():
		existing[child.get_meta("action_instance_id", -1)] = child
	for index in range(visible_actions.size()):
		var action: Dictionary = visible_actions[index]
		if not action.has_all(["action_instance_id", "source_id", "action_name", "trigger_time"]):
			push_error("[CombatHUD] 敌方行动快照缺少必需字段。")
			continue
		var identity: int = int(action.action_instance_id)
		var icon: Panel = existing.get(identity) as Panel
		if icon == null:
			icon = intent_template.duplicate() as Panel
			icon.show()
			intent_row.add_child(icon)
			icon.pivot_offset = icon.custom_minimum_size * 0.5
			icon.mouse_entered.connect(_on_intent_mouse_entered.bind(icon))
			icon.mouse_exited.connect(_on_intent_mouse_exited.bind(icon))
		icon.set_meta("action_instance_id", identity)
		icon.set_meta("action_display", action.duplicate())
		intent_row.move_child(icon, index)
		existing.erase(identity)
	for icon in existing.values():
		_stop_intent_scale_tween(icon)
		if icon == _hovered_intent:
			hide_intent_tooltip()
		intent_row.remove_child(icon)
		icon.queue_free()
	if _hovered_intent != null:
		if not is_instance_valid(_hovered_intent) or _hovered_intent.get_meta("action_instance_id", -1) != _hovered_action_id:
			hide_intent_tooltip()
		else:
			_show_intent_data(_hovered_intent.get_meta("action_display", {}))


# 只按行动实例身份缩放已有图标，不改变容器布局或行动数据。
func _set_intent_preview(action_ids: Array) -> void:
	_preview_action_ids.clear()
	for identity in action_ids:
		_preview_action_ids.append(int(identity))
	for icon in intent_row.get_children():
		var active := _preview_action_ids.has(int(icon.get_meta("action_instance_id", -1)))
		if bool(icon.get_meta("preview_active", false)) == active:
			continue
		icon.set_meta("preview_active", active)
		_stop_intent_scale_tween(icon)
		var target := Vector2.ONE * (intent_preview_scale if active else 1.0)
		if intent_preview_duration <= 0.0:
			icon.scale = target
		else:
			var tween := icon.create_tween()
			icon.set_meta("preview_tween", tween)
			tween.tween_property(icon, "scale", target, intent_preview_duration)


# 图标切换状态或移除前停止旧动画。
func _stop_intent_scale_tween(icon: Control) -> void:
	if not icon.has_meta("preview_tween"):
		return
	var tween := icon.get_meta("preview_tween") as Tween
	if tween != null and tween.is_running():
		tween.kill()
	icon.remove_meta("preview_tween")


# 输入锁、弃牌模式与战斗关闭时立即清空全部高亮身份。
func clear_intent_preview() -> void:
	_set_intent_preview([])


# 进入行动方块时只读取该节点保存的显示快照。
func _on_intent_mouse_entered(icon: Panel) -> void:
	if not is_visible_in_tree() or not is_instance_valid(icon):
		return
	var action: Dictionary = icon.get_meta("action_display", {})
	if not action.has_all(["action_instance_id", "action_name", "trigger_time", "relative_time"]):
		hide_intent_tooltip()
		return
	_hovered_intent = icon
	_hovered_action_id = int(action.action_instance_id)
	_show_intent_data(action)


# 只允许当前图标的离开事件关闭提示，避免相邻图标交接时误关。
func _on_intent_mouse_exited(icon: Panel) -> void:
	if icon == _hovered_intent:
		hide_intent_tooltip()


# 记录视口输入坐标，供悬停提示和逐帧有效性检查共用。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_viewport_position = event.position


# 从明确的快照字段组装简短文本，不展示内部实例标识。
func _show_intent_data(action: Dictionary) -> void:
	if action.is_empty() or not action.has_all(["action_instance_id", "trigger_time", "relative_time"]):
		hide_intent_tooltip()
		return
	var action_name := String(action.get("action_name", "")).strip_edges()
	var lines: PackedStringArray = [action_name if not action_name.is_empty() else "未命名行动"]
	var action_type := String(action.get("action_type", ""))
	if not action_type.is_empty():
		var type_name: String = {"attack": "攻击", "buff": "增益", "skill": "技能"}.get(action_type, action_type)
		lines.append("类型：%s" % type_name)
	lines.append("触发：T=%d（剩余 %d）" % [int(action.trigger_time), int(action.relative_time)])
	if action.has("base_damage"):
		lines.append("基础伤害：%s" % _format_number(float(action.base_damage)))
	if action.has("shield_gain"):
		lines.append("护盾增加：%s" % _format_number(float(action.shield_gain)))
	intent_tooltip_label.text = "\n".join(lines)
	intent_tooltip.show()
	intent_tooltip.reset_size()
	set_process(true)
	_last_mouse_position = Vector2.INF
	_position_intent_tooltip.call_deferred()


# 控件位于 CanvasLayer 内，将视口鼠标位置转到 HUD 局部坐标并翻转越界方向。
func _position_intent_tooltip() -> void:
	if not intent_tooltip.visible or not is_visible_in_tree():
		return
	var viewport_rect := get_viewport().get_visible_rect()
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var mouse_viewport := _mouse_viewport_position
	if mouse_viewport == Vector2.INF:
		mouse_viewport = get_viewport().get_mouse_position()
	var mouse_local := inverse * mouse_viewport
	var offset := inverse * (mouse_viewport + Vector2(16.0, 20.0)) - mouse_local
	var left_top := inverse * viewport_rect.position
	var right_bottom := inverse * viewport_rect.end
	var tip_size := intent_tooltip.size
	var target := mouse_local + offset
	if target.x + tip_size.x > right_bottom.x:
		target.x = mouse_local.x - offset.x - tip_size.x
	if target.y + tip_size.y > right_bottom.y:
		target.y = mouse_local.y - offset.y - tip_size.y
	target.x = clampf(target.x, left_top.x, maxf(left_top.x, right_bottom.x - tip_size.x))
	target.y = clampf(target.y, left_top.y, maxf(left_top.y, right_bottom.y - tip_size.y))
	intent_tooltip.position = target
	_last_mouse_position = mouse_viewport


# 提示可见时才跟踪鼠标，并防止图标或战斗界面失效后残留。
func _process(_delta: float) -> void:
	if _hovered_intent == null or not is_instance_valid(_hovered_intent) or not is_visible_in_tree():
		hide_intent_tooltip()
		return
	var mouse_viewport := _mouse_viewport_position
	if mouse_viewport == Vector2.INF:
		mouse_viewport = get_viewport().get_mouse_position()
	var local_mouse := _hovered_intent.get_global_transform_with_canvas().affine_inverse() * mouse_viewport
	if not Rect2(Vector2.ZERO, _hovered_intent.size).has_point(local_mouse):
		hide_intent_tooltip()
		return
	if mouse_viewport != _last_mouse_position:
		_position_intent_tooltip()


# 隐藏时同步清理图标身份和逐帧跟踪。
func hide_intent_tooltip() -> void:
	_hovered_intent = null
	_hovered_action_id = -1
	intent_tooltip.hide()
	set_process(false)


func _on_hud_visibility_changed() -> void:
	if not is_visible_in_tree():
		hide_intent_tooltip()
		clear_intent_preview()


# 菱形数量固定为四格，亮度只表示当前资源比例。
func _set_pips(group: Control, current: float, maximum: float) -> void:
	var pip_count := group.get_child_count()
	var ratio := clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	for index in range(pip_count):
		var pip := group.get_child(index) as CanvasItem
		if pip != null:
			pip.modulate.a = 1.0 if float(index + 1) / pip_count <= ratio else 0.25


# 整数省略小数位，其余显示一位小数。
func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value
