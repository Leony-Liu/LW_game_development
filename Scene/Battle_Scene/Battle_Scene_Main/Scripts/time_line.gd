extends Control

# 整条行动轴代表的未来时间范围。
const VISIBLE_RANGE: int = 100


@export_category("行动标记")
@export var action_marker_scene: PackedScene = preload(
	"res://Scene/Battle_Scene/"
	+ "Battle_Scene_Main/actions.tscn"
)

@export var enemy_stack_gap: float = 28.0
@export var resource_stack_gap: float = 20.0


@export_category("时间移动动画")
# 每推进 10 时间所用的动画秒数。
@export var move_duration_per_10_time: float = 0.6

@export var minimum_move_duration: float = 0.08
@export var maximum_move_duration: float = 0.35


@export_category("图标缩放")
@export var preview_highlight_scale: float = 1.28
@export var active_action_scale: float = 1.45
@export var scale_animation_duration: float = 0.10


@export_category("推进条")
@export var preview_line_height: float = 5.0


@export_category("资源颜色")
@export var stamina_marker_color: Color = Color(
	1.0,
	0.55,
	0.05,
	1.0
)

@export var mana_marker_color: Color = Color(
	0.1,
	0.65,
	1.0,
	1.0
)


@onready var action_slot: Control = $ActionSlot
@onready var timeline_line: ColorRect = $line

@onready var card_time_preview: ColorRect = (
	$CardTimePreview
)

@onready var detail_list: VBoxContainer = (
	get_node_or_null("DetailList")
	as VBoxContainer
)


var timeline_manager: ActionTimelineManager = null
var player_combat_data: PlayerCombatData = null

# sequence_id -> 敌人图标实例
var enemy_markers: Dictionary = {}

# "资源类型:绝对时间" -> 资源图标实例
var resource_markers: Dictionary = {}

# 当前正在执行的敌人行动。
var active_enemy_action: TimelineAction = null

# 当前鼠标指向的敌人行动。
var hovered_enemy_action: TimelineAction = null

# 当前悬停的卡牌。
var hover_preview_source: Control = null
var hover_preview_time: int = 0

# 卡牌已打出后，尚未推进完的时间。
var committed_preview_remaining: float = 0.0


func _ready() -> void:
	if action_slot == null:
		push_error(
			"TimeLine：找不到 ActionSlot，"
			+ "请检查节点名称并保存 time_line.tscn。"
		)
		return

	if timeline_line == null:
		push_error(
			"TimeLine：找不到 line 节点。"
		)
		return

	if card_time_preview == null:
		push_error(
			"TimeLine：找不到 CardTimePreview 节点。"
		)
		return

	if detail_list == null:
		push_error(
			"TimeLine：找不到 VBoxContainer 类型的 DetailList。"
			+ "请确认节点名称、节点类型，并保存场景。"
		)
		return

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	timeline_line.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	card_time_preview.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	detail_list.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	timeline_line.z_index = 0
	card_time_preview.z_index = 1
	action_slot.z_index = 2
	detail_list.z_index = 10

	card_time_preview.visible = false
	detail_list.visible = false

	if not resized.is_connected(
		_on_timeline_resized
	):
		resized.connect(
			_on_timeline_resized
		)

	call_deferred(
		"_bind_data_sources"
	)


func _bind_data_sources() -> void:
	var scene_root := get_tree().current_scene

	if scene_root == null:
		push_error(
			"TimeLine：当前没有有效场景。"
		)
		return

	var all_nodes := scene_root.find_children(
		"*",
		"",
		true,
		false
	)

	for candidate in all_nodes:
		if (
			timeline_manager == null
			and candidate is ActionTimelineManager
		):
			timeline_manager = (
				candidate as ActionTimelineManager
			)

		if (
			player_combat_data == null
			and candidate is PlayerCombatData
		):
			player_combat_data = (
				candidate as PlayerCombatData
			)

		if (
			timeline_manager != null
			and player_combat_data != null
		):
			break

	if timeline_manager == null:
		push_error(
			"TimeLine：找不到 ActionTimelineManager。"
		)
		return

	if player_combat_data == null:
		push_error(
			"TimeLine：找不到 PlayerCombatData。"
		)
		return

	_connect_timeline_signals()
	_connect_card_signals()
	_connect_resource_signals()

	_rebuild_timeline()


func _connect_timeline_signals() -> void:
	if not timeline_manager.timeline_changed.is_connected(
		_on_timeline_changed
	):
		timeline_manager.timeline_changed.connect(
			_on_timeline_changed
		)

	if not timeline_manager.time_visual_move_requested.is_connected(
		_on_time_visual_move_requested
	):
		timeline_manager.time_visual_move_requested.connect(
			_on_time_visual_move_requested
		)

	if not timeline_manager.action_resolution_started.is_connected(
		_on_action_resolution_started
	):
		timeline_manager.action_resolution_started.connect(
			_on_action_resolution_started
		)

	if not timeline_manager.action_resolved.is_connected(
		_on_action_resolved
	):
		timeline_manager.action_resolved.connect(
			_on_action_resolved
		)

	if not timeline_manager.time_advance_finished.is_connected(
		_on_time_advance_finished
	):
		timeline_manager.time_advance_finished.connect(
			_on_time_advance_finished
		)


func _connect_card_signals() -> void:
	if not BattleBus.card_timeline_preview_requested.is_connected(
		_on_card_timeline_preview_requested
	):
		BattleBus.card_timeline_preview_requested.connect(
			_on_card_timeline_preview_requested
		)

	if not BattleBus.card_timeline_preview_cleared.is_connected(
		_on_card_timeline_preview_cleared
	):
		BattleBus.card_timeline_preview_cleared.connect(
			_on_card_timeline_preview_cleared
		)

	if not BattleBus.card_timeline_preview_committed.is_connected(
		_on_card_timeline_preview_committed
	):
		BattleBus.card_timeline_preview_committed.connect(
			_on_card_timeline_preview_committed
		)


func _connect_resource_signals() -> void:
	if not BattleBus.player_stamina_changed.is_connected(
		_on_player_resource_changed
	):
		BattleBus.player_stamina_changed.connect(
			_on_player_resource_changed
		)

	if not BattleBus.player_mana_changed.is_connected(
		_on_player_resource_changed
	):
		BattleBus.player_mana_changed.connect(
			_on_player_resource_changed
		)


func _on_timeline_changed(
	_actions: Array[TimelineAction],
	_current_time: int
) -> void:
	_rebuild_timeline()


func _on_player_resource_changed(
	_current_value: int,
	_max_value: int
) -> void:
	_rebuild_timeline()


func _on_timeline_resized() -> void:
	call_deferred(
		"_rebuild_timeline"
	)


func _rebuild_timeline() -> void:
	if timeline_manager == null:
		return

	if player_combat_data == null:
		return

	if timeline_line.size.x <= 0.0:
		return

	_sync_enemy_action_markers()
	_sync_resource_markers()

	_refresh_preview_visuals(false)
	_refresh_detail_list()


# ============================================================
# 敌方行动图标
# ============================================================

func _sync_enemy_action_markers() -> void:
	var visible_actions := (
		timeline_manager.get_visible_actions(
			VISIBLE_RANGE
		)
	)

	var live_sequence_ids: Dictionary = {}
	var stack_counts: Dictionary = {}

	for action: TimelineAction in visible_actions:
		if action == null:
			continue

		if (
			action.actor_side
			!= TimelineAction.ActorSide.ENEMY
		):
			continue

		var remaining_time := (
			action.execute_time
			- timeline_manager.current_time
		)

		if remaining_time < 0:
			continue

		if remaining_time > VISIBLE_RANGE:
			continue

		var sequence_id := action.sequence_id
		live_sequence_ids[sequence_id] = true

		var marker := _get_enemy_marker(
			sequence_id
		)

		if marker == null:
			marker = _create_enemy_action_marker(
				action
			)

			enemy_markers[sequence_id] = marker

		var stack_index := int(
			stack_counts.get(
				action.execute_time,
				0
			)
		)

		stack_counts[action.execute_time] = (
			stack_index + 1
		)

		var base_y := (
			_get_line_center_y()
			- enemy_stack_gap
			* float(stack_index)
		)

		marker.set_meta(
			"action",
			action
		)

		marker.set_meta(
			"absolute_time",
			float(action.execute_time)
		)

		marker.set_meta(
			"remaining_time",
			float(remaining_time)
		)

		marker.set_meta(
			"base_y",
			base_y
		)

		var marker_x := _remaining_time_to_x(
			float(remaining_time)
		)

		if (
			active_enemy_action != null
			and active_enemy_action.sequence_id
			== sequence_id
		):
			marker_x = timeline_line.position.x

		marker.position = Vector2(
			marker_x,
			base_y
		)

		_update_marker_scale(
			marker,
			false
		)

	var marker_keys := (
		enemy_markers.keys().duplicate()
	)

	for raw_sequence_id in marker_keys:
		var sequence_id := int(raw_sequence_id)

		if live_sequence_ids.has(sequence_id):
			continue

		# 当前正在执行的行动虽然已离开 pending_actions，
		# 但必须保留到角色动作真正完成。
		if (
			active_enemy_action != null
			and active_enemy_action.sequence_id
			== sequence_id
		):
			continue

		_remove_enemy_marker_immediately(
			sequence_id
		)


func _create_enemy_action_marker(
	action: TimelineAction
) -> Control:
	var category := _get_enemy_action_category(
		action
	)

	var visual_name := (
		"Rectangle"
		if category == "skill"
		else "Triangle"
	)

	var marker := _create_marker(
		visual_name,
		Color.WHITE
	)

	if marker == null:
		return null

	_create_enemy_hover_area(
		marker,
		action
	)

	return marker


func _get_enemy_action_category(
	action: TimelineAction
) -> String:
	var category := str(
		action.payload.get(
			"category",
			""
		)
	)

	if category != "":
		return category

	var action_data := _get_action_data(action)

	return str(
		action_data.get(
			"category",
			""
		)
	)


func _get_enemy_marker(
	sequence_id: int
) -> Control:
	return enemy_markers.get(
		sequence_id,
		null
	) as Control


func _remove_enemy_marker_immediately(
	sequence_id: int
) -> void:
	var marker := _get_enemy_marker(
		sequence_id
	)

	if marker == null:
		enemy_markers.erase(sequence_id)
		return

	var action_variant = marker.get_meta(
		"action",
		null
	)

	if (
		hovered_enemy_action != null
		and action_variant == hovered_enemy_action
	):
		hovered_enemy_action = null

	enemy_markers.erase(sequence_id)
	marker.queue_free()

	_refresh_detail_list()


# ============================================================
# 玩家资源恢复图标
# ============================================================

func _sync_resource_markers() -> void:
	var recovery_events := (
		player_combat_data
		.get_resource_recovery_preview(
			VISIBLE_RANGE
		)
	)

	var live_keys: Dictionary = {}
	var stack_counts: Dictionary = {}

	for event: Dictionary in recovery_events:
		var remaining_time := float(
			event.get(
				"remaining_time",
				-1.0
			)
		)

		if remaining_time < 0.0:
			continue

		if (
			remaining_time
			> float(VISIBLE_RANGE) + 0.001
		):
			continue

		var resource_type := str(
			event.get(
				"resource_type",
				""
			)
		)

		var marker_color := Color.WHITE

		match resource_type:
			"stamina":
				marker_color = stamina_marker_color

			"mana":
				marker_color = mana_marker_color

			_:
				continue

		var absolute_time := (
			float(timeline_manager.current_time)
			+ remaining_time
		)

		var resource_key := (
			"%s:%.3f"
			% [
				resource_type,
				absolute_time
			]
		)

		live_keys[resource_key] = true

		var marker := resource_markers.get(
			resource_key,
			null
		) as Control

		if marker == null:
			marker = _create_marker(
				"Circle",
				marker_color
			)

			if marker == null:
				push_error(
					"TimeLine：资源恢复图标创建失败，"
					+ "resource_key=%s。"
					% resource_key
				)
				continue

			resource_markers[resource_key] = marker

		var stack_key := roundi(
			absolute_time * 1000.0
		)

		var stack_index := int(
			stack_counts.get(
				stack_key,
				0
			)
		)

		stack_counts[stack_key] = (
			stack_index + 1
		)

		var base_y := (
			_get_line_center_y()
			+ resource_stack_gap
			* float(stack_index)
		)

		marker.set_meta(
			"absolute_time",
			absolute_time
		)

		marker.set_meta(
			"remaining_time",
			remaining_time
		)

		marker.set_meta(
			"base_y",
			base_y
		)

		marker.position = Vector2(
			_remaining_time_to_x(
				remaining_time
			),
			base_y
		)

		_update_marker_scale(
			marker,
			false
		)

	var resource_keys := (
		resource_markers.keys().duplicate()
	)

	for raw_key in resource_keys:
		var key := str(raw_key)

		if live_keys.has(key):
			continue

		var marker := resource_markers.get(
			key,
			null
		) as Control

		resource_markers.erase(key)

		if marker != null:
			marker.queue_free()


# ============================================================
# 图标实例
# ============================================================

func _create_marker(
	selected_visual_name: String,
	marker_color: Color
) -> Control:
	if action_marker_scene == null:
		push_error(
			"TimeLine：没有绑定 actions.tscn。"
		)
		return null

	var marker := (
		action_marker_scene.instantiate()
		as Control
	)

	if marker == null:
		push_error(
			"TimeLine：actions.tscn 根节点不是 Control。"
		)
		return null

	action_slot.add_child(marker)

	marker.scale = Vector2.ONE
	marker.modulate = Color.WHITE
	marker.z_index = 2

	marker.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	for visual_name: String in [
		"Circle",
		"Triangle",
		"Rectangle"
	]:
		var visual := marker.get_node_or_null(
			visual_name
		) as TextureRect

		if visual == null:
			continue

		visual.visible = (
			visual_name == selected_visual_name
		)

		visual.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

	var selected_visual := marker.get_node_or_null(
		selected_visual_name
	) as TextureRect

	if selected_visual != null:
		selected_visual.self_modulate = marker_color

	return marker


# 敌人图标专用的透明鼠标接收区域。
func _create_enemy_hover_area(
	marker: Control,
	action: TimelineAction
) -> void:
	var hover_area := Control.new()

	hover_area.name = "HoverArea"
	hover_area.position = Vector2(
		-15.0,
		-30.0
	)

	hover_area.size = Vector2(
		30.0,
		32.0
	)

	hover_area.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	hover_area.z_index = 20

	marker.add_child(hover_area)

	hover_area.mouse_entered.connect(
		_on_enemy_marker_mouse_entered.bind(
			action
		)
	)

	hover_area.mouse_exited.connect(
		_on_enemy_marker_mouse_exited.bind(
			action
		)
	)


# ============================================================
# 时间移动动画
# ============================================================

func _on_time_visual_move_requested(
	from_time: int,
	to_time: int
) -> void:
	if timeline_manager == null:
		push_error(
			"TimeLine：收到移动请求时，"
			+ "timeline_manager 仍然为空。"
		)
		return

	# 节点缺失时必须主动结束视觉等待，
	# 否则 ActionTimelineManager 会等待到超时。
	if timeline_line == null:
		push_error(
			"TimeLine：缺少 line 节点，"
			+ "无法播放移动动画。"
		)
		timeline_manager.finish_time_visual_move()
		return

	if action_slot == null:
		push_error(
			"TimeLine：缺少 ActionSlot，"
			+ "无法播放移动动画。"
		)
		timeline_manager.finish_time_visual_move()
		return

	if card_time_preview == null:
		push_error(
			"TimeLine：缺少 CardTimePreview，"
			+ "无法播放推进条动画。"
		)
		timeline_manager.finish_time_visual_move()
		return

	var elapsed_time := maxi(
		to_time - from_time,
		0
	)

	if elapsed_time <= 0:
		timeline_manager.finish_time_visual_move()
		return

	var duration := clampf(
		float(elapsed_time)
		/ 10.0
		* move_duration_per_10_time,
		minimum_move_duration,
		maximum_move_duration
	)

	# 使用快照，避免等待 Tween 期间字典内容变化。
	var markers: Array[Control] = _get_all_markers()
	var tween := create_tween().set_parallel(true)
	var has_animation := false

	for marker: Control in markers:
		if marker == null:
			continue

		if not is_instance_valid(marker):
			continue

		var absolute_time := float(
			marker.get_meta(
				"absolute_time",
				float(to_time)
			)
		)

		var target_remaining := maxf(
			absolute_time - float(to_time),
			0.0
		)

		var base_y := float(
			marker.get_meta(
				"base_y",
				marker.position.y
			)
		)

		var target_position := Vector2(
			_remaining_time_to_x(
				target_remaining
			),
			base_y
		)

		tween.tween_property(
			marker,
			"position",
			target_position,
			duration
		).set_trans(
			Tween.TRANS_QUAD
		).set_ease(
			Tween.EASE_IN_OUT
		)

		has_animation = true

	var target_committed_remaining := maxf(
		committed_preview_remaining
		- float(elapsed_time),
		0.0
	)

	if committed_preview_remaining > 0.0:
		var target_width := (
			timeline_line.size.x
			* minf(
				target_committed_remaining,
				float(VISIBLE_RANGE)
			)
			/ float(VISIBLE_RANGE)
		)

		var preview_target_size := Vector2(
			target_width,
			maxf(
				preview_line_height,
				timeline_line.size.y
			)
		)

		card_time_preview.visible = true

		tween.tween_property(
			card_time_preview,
			"size",
			preview_target_size,
			duration
		).set_trans(
			Tween.TRANS_QUAD
		).set_ease(
			Tween.EASE_IN_OUT
		)

		has_animation = true

	if has_animation:
		await tween.finished

	committed_preview_remaining = (
		target_committed_remaining
	)

	for marker: Control in markers:
		if marker == null:
			continue

		if not is_instance_valid(marker):
			continue

		var absolute_time := float(
			marker.get_meta(
				"absolute_time",
				float(to_time)
			)
		)

		marker.set_meta(
			"remaining_time",
			maxf(
				absolute_time - float(to_time),
				0.0
			)
		)

	_refresh_preview_visuals(false)

	# 无论有没有图标，都必须通知管理器继续推进逻辑时间。
	if (
		timeline_manager != null
		and is_instance_valid(timeline_manager)
	):
		timeline_manager.finish_time_visual_move()


func _get_all_markers() -> Array[Control]:
	var result: Array[Control] = []

	for marker_variant in enemy_markers.values():
		var marker := marker_variant as Control

		if marker != null:
			result.append(marker)

	for marker_variant in resource_markers.values():
		var marker := marker_variant as Control

		if marker != null:
			result.append(marker)

	return result


# ============================================================
# 当前行动停留与完成
# ============================================================

func _on_action_resolution_started(
	action: TimelineAction
) -> void:
	if action == null:
		return

	if (
		action.actor_side
		!= TimelineAction.ActorSide.ENEMY
	):
		return

	active_enemy_action = action

	var marker := _get_enemy_marker(
		action.sequence_id
	)

	if marker == null:
		marker = _create_enemy_action_marker(
			action
		)

		if marker == null:
			push_error(
				"TimeLine：当前行动图标创建失败，"
				+ "sequence_id=%d。"
				% action.sequence_id
			)
			active_enemy_action = null
			return

		enemy_markers[action.sequence_id] = marker

	marker.set_meta(
		"action",
		action
	)

	marker.set_meta(
		"absolute_time",
		float(action.execute_time)
	)

	marker.set_meta(
		"remaining_time",
		0.0
	)

	marker.set_meta(
		"base_y",
		_get_line_center_y()
	)

	marker.position.x = timeline_line.position.x
	marker.z_index = 8

	_update_marker_scale(
		marker,
		true
	)


func _on_action_resolved(
	action: TimelineAction
) -> void:
	if action == null:
		return

	if (
		action.actor_side
		!= TimelineAction.ActorSide.ENEMY
	):
		return

	var marker := _get_enemy_marker(
		action.sequence_id
	)

	if (
		hovered_enemy_action != null
		and hovered_enemy_action.sequence_id
		== action.sequence_id
	):
		hovered_enemy_action = null

	active_enemy_action = null
	_refresh_detail_list()

	if marker == null:
		enemy_markers.erase(
			action.sequence_id
		)
		return

	var tween := marker.create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		marker,
		"scale",
		Vector2.ONE * 0.75,
		0.12
	)

	tween.tween_property(
		marker,
		"modulate:a",
		0.0,
		0.12
	)

	await tween.finished

	enemy_markers.erase(
		action.sequence_id
	)

	if is_instance_valid(marker):
		marker.queue_free()


# ============================================================
# 卡牌悬停与正式推进条
# ============================================================

func _on_card_timeline_preview_requested(
	card_node: Control,
	time_cost: int
) -> void:
	if card_node == null:
		return

	hover_preview_source = card_node
	hover_preview_time = maxi(
		time_cost,
		0
	)

	_refresh_preview_visuals(true)
	_refresh_detail_list()


func _on_card_timeline_preview_cleared(
	card_node: Control
) -> void:
	if hover_preview_source != card_node:
		return

	hover_preview_source = null
	hover_preview_time = 0

	_refresh_preview_visuals(true)
	_refresh_detail_list()


func _on_card_timeline_preview_committed(
	time_cost: int
) -> void:
	committed_preview_remaining = float(
		maxi(
			time_cost,
			0
		)
	)

	# 正式推进阶段不再显示悬停卡牌的多行动详情。
	hover_preview_source = null
	hover_preview_time = 0

	_refresh_preview_visuals(false)
	_refresh_detail_list()


func _on_time_advance_finished(
	_current_time: int
) -> void:
	committed_preview_remaining = 0.0

	_refresh_preview_visuals(true)
	_refresh_detail_list()


func _get_effective_preview_time() -> float:
	if committed_preview_remaining > 0.0:
		return committed_preview_remaining

	if (
		hover_preview_source != null
		and is_instance_valid(
			hover_preview_source
		)
	):
		return float(hover_preview_time)

	return 0.0


func _refresh_preview_visuals(
	animate: bool
) -> void:
	var effective_preview_time := (
		_get_effective_preview_time()
	)

	if effective_preview_time <= 0.0:
		card_time_preview.visible = false

		for marker: Control in _get_all_markers():
			_update_marker_scale(
				marker,
				animate
			)

		return

	var visible_preview_time := minf(
		effective_preview_time,
		float(VISIBLE_RANGE)
	)

	var preview_height := maxf(
		preview_line_height,
		timeline_line.size.y
	)

	card_time_preview.visible = true

	card_time_preview.position = Vector2(
		timeline_line.position.x,
		_get_line_center_y()
		- preview_height * 0.5
	)

	var target_size := Vector2(
		timeline_line.size.x
		* visible_preview_time
		/ float(VISIBLE_RANGE),
		preview_height
	)

	if animate:
		var tween := card_time_preview.create_tween()

		tween.tween_property(
			card_time_preview,
			"size",
			target_size,
			scale_animation_duration
		)
	else:
		card_time_preview.size = target_size

	for marker: Control in _get_all_markers():
		_update_marker_scale(
			marker,
			animate
		)


func _update_marker_scale(
	marker: Control,
	animate: bool
) -> void:
	if marker == null:
		return

	if not is_instance_valid(marker):
		return

	var target_scale := Vector2.ONE

	# 资源恢复图标没有 action 元数据，
	# 因此必须先通过 has_meta() 检查。
	var action_variant = null

	if marker.has_meta(&"action"):
		action_variant = marker.get_meta(
			&"action"
		)

	if (
		active_enemy_action != null
		and action_variant == active_enemy_action
	):
		target_scale *= active_action_scale
	else:
		var effective_preview_time := (
			_get_effective_preview_time()
		)

		var remaining_time := 999999.0

		if marker.has_meta(&"remaining_time"):
			remaining_time = float(
				marker.get_meta(
					&"remaining_time"
				)
			)

		if (
			effective_preview_time > 0.0
			and remaining_time
			<= effective_preview_time + 0.001
		):
			target_scale *= preview_highlight_scale

	# 先结束旧缩放 Tween。
	# 新创建的图标第一次进入这里时还没有 scale_tween，
	# 所以也必须先检查 has_meta()。
	if marker.has_meta(&"scale_tween"):
		var old_tween_variant = marker.get_meta(
			&"scale_tween"
		)

		if old_tween_variant is Tween:
			var old_tween := old_tween_variant as Tween

			if old_tween.is_valid():
				old_tween.kill()

	if not animate:
		marker.scale = target_scale
		return

	var tween := marker.create_tween()

	tween.tween_property(
		marker,
		"scale",
		target_scale,
		scale_animation_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	marker.set_meta(
		&"scale_tween",
		tween
	)


# ============================================================
# 敌人行动详情
# ============================================================

func _on_enemy_marker_mouse_entered(
	action: TimelineAction
) -> void:
	if action == null:
		return

	hovered_enemy_action = action
	_refresh_detail_list()


func _on_enemy_marker_mouse_exited(
	action: TimelineAction
) -> void:
	if hovered_enemy_action != action:
		return

	hovered_enemy_action = null
	_refresh_detail_list()


func _refresh_detail_list() -> void:
	_clear_detail_list()

	var detail_lines: Array[String] = []

	# 单独指向敌方图标时，优先只显示该行动。
	if hovered_enemy_action != null:
		detail_lines.append(
			_format_enemy_action_detail(
				hovered_enemy_action
			)
		)

	# 卡牌纯悬停阶段，显示推进范围内所有敌人行动。
	elif (
		hover_preview_source != null
		and is_instance_valid(
			hover_preview_source
		)
		and hover_preview_time > 0
		and committed_preview_remaining <= 0.0
	):
		var actions := (
			timeline_manager.get_visible_actions(
				VISIBLE_RANGE
			)
		)

		for action: TimelineAction in actions:
			if action == null:
				continue

			if (
				action.actor_side
				!= TimelineAction.ActorSide.ENEMY
			):
				continue

			var remaining_time := (
				action.execute_time
				- timeline_manager.current_time
			)

			if remaining_time < 0:
				continue

			if remaining_time > hover_preview_time:
				continue

			detail_lines.append(
				_format_enemy_action_detail(
					action
				)
			)

		if detail_lines.is_empty():
			detail_lines.append(
				"推进范围内无敌方行动"
			)

	if detail_lines.is_empty():
		detail_list.visible = false
		return

	for detail_text: String in detail_lines:
		var label := Label.new()

		label.text = detail_text
		label.custom_minimum_size = Vector2(
			420.0,
			0.0
		)

		label.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)

		label.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		label.add_theme_font_size_override(
			"font_size",
			15
		)

		label.add_theme_color_override(
			"font_outline_color",
			Color.BLACK
		)

		label.add_theme_constant_override(
			"outline_size",
			4
		)

		detail_list.add_child(label)

	detail_list.visible = true


func _clear_detail_list() -> void:
	for child in detail_list.get_children():
		detail_list.remove_child(child)
		child.queue_free()


func _format_enemy_action_detail(
	action: TimelineAction
) -> String:
	var action_data := _get_action_data(
		action
	)

	var action_name := str(
		action_data.get(
			"name",
			action.action_name
		)
	)

	var explicit_description := str(
		action_data.get(
			"description",
			""
		)
	)

	if explicit_description != "":
		return (
			"%s - %s"
			% [
				tr(action_name),
				tr(explicit_description)
			]
		)

	var effect_type := str(
		action_data.get(
			"effect_type",
			action.payload.get(
				"effect_type",
				""
			)
		)
	)

	var effect_description := ""

	match effect_type:
		"damage":
			var damage := int(
				action_data.get(
					"damage",
					0
				)
			)

			effect_description = (
				"造成 %d 点伤害"
				% damage
			)

		"multi_damage":
			var hit_count := int(
				action_data.get(
					"hit_count",
					1
				)
			)

			var damage_per_hit := int(
				action_data.get(
					"damage_per_hit",
					0
				)
			)

			effect_description = (
				"连续攻击 %d 次，每次 %d 点伤害"
				% [
					hit_count,
					damage_per_hit
				]
			)

		"dodge_buff":
			var dodge_bonus := float(
				action_data.get(
					"dodge_bonus",
					0.0
				)
			)

			var duration := int(
				action_data.get(
					"duration",
					0
				)
			)

			effect_description = (
				"闪避率提高 %d%%，持续 %d 时间"
				% [
					roundi(
						dodge_bonus * 100.0
					),
					duration
				]
			)

		"block_next_attack":
			var charges := int(
				action_data.get(
					"charges",
					1
				)
			)

			var duration := int(
				action_data.get(
					"duration",
					0
				)
			)

			effect_description = (
				"格挡接下来 %d 次攻击，持续 %d 时间"
				% [
					charges,
					duration
				]
			)

		"rebirth_charge":
			var charge_amount := int(
				action_data.get(
					"charge_amount",
					1
				)
			)

			effect_description = (
				"获得 %d 层重生充能"
				% charge_amount
			)

		_:
			effect_description = (
				"效果类型：%s"
				% effect_type
			)

	return (
		"%s - %s"
		% [
			tr(action_name),
			effect_description
		]
	)


func _get_action_data(
	action: TimelineAction
) -> Dictionary:
	if action == null:
		return {}

	var action_data_variant = action.payload.get(
		"action_data",
		{}
	)

	if (
		typeof(action_data_variant)
		!= TYPE_DICTIONARY
	):
		return {}

	return action_data_variant as Dictionary


# ============================================================
# 坐标换算
# ============================================================

func _remaining_time_to_x(
	remaining_time: float
) -> float:
	var ratio := clampf(
		remaining_time
		/ float(VISIBLE_RANGE),
		0.0,
		1.0
	)

	return (
		timeline_line.position.x
		+ timeline_line.size.x
		* ratio
	)


func _get_line_center_y() -> float:
	return (
		timeline_line.position.y
		+ timeline_line.size.y * 0.5
	)
