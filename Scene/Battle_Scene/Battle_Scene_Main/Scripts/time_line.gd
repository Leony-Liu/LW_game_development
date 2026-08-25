extends Control

# 整条行动轴代表的未来时间范围。
const VISIBLE_RANGE: int = 100

@export_category("行动标记")
@export var action_marker_scene: PackedScene = preload("res://Scene/Battle_Scene/Battle_Scene_Main/actions.tscn")
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
@export var stamina_marker_color: Color = Color(1.0, 0.55, 0.05, 1.0)
@export var mana_marker_color: Color = Color(0.1, 0.65, 1.0, 1.0)

@onready var action_slot: Control = $ActionSlot
@onready var timeline_line: ColorRect = $line
@onready var card_time_preview: ColorRect = $CardTimePreview
@onready var detail_list: VBoxContainer = get_node_or_null("DetailList") as VBoxContainer

var timeline_manager: TimelineManager = null
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

# 节点准备就绪时校验UI组件状态并初始化事件监听
func _ready() -> void:
	# 检查核心UI节点是否有效，缺失则抛出错误并中止
	if action_slot == null:
		push_error("TimeLine：找不到 ActionSlot，请检查节点名称并保存 time_line.tscn。")
		return
	if timeline_line == null:
		push_error("TimeLine：找不到 line 节点。")
		return
	if card_time_preview == null:
		push_error("TimeLine：找不到 CardTimePreview 节点。")
		return
	if detail_list == null:
		push_error("TimeLine：找不到 VBoxContainer 类型的 DetailList。请确认节点名称、节点类型，并保存场景。")
		return

	# 设置节点的鼠标过滤模式，避免阻挡底层输入
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timeline_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_time_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_list.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 划分不同UI层级的Z轴顺序
	timeline_line.z_index = 0
	card_time_preview.z_index = 1
	action_slot.z_index = 2
	detail_list.z_index = 10

	# 隐藏默认不需要显示的预览和详情节点
	card_time_preview.visible = false
	detail_list.visible = false

	# 绑定容器尺寸变更信号以便响应式刷新时间轴
	if not resized.is_connected(_on_timeline_resized):
		resized.connect(_on_timeline_resized)

	# 延迟执行数据源绑定，确保场景树已经构建完毕
	call_deferred("_bind_data_sources")

# 遍历场景树自动寻找并绑定时间轴与战斗数据管理器
func _bind_data_sources() -> void:
	# 获取当前根场景并校验
	var scene_root := get_tree().current_scene
	if scene_root == null:
		push_error("TimeLine：当前没有有效场景。")
		return

	# 通过递归查找所有子节点来定位管理器实例
	var all_nodes := scene_root.find_children("*", "", true, false)
	for candidate in all_nodes:
		if timeline_manager == null and candidate is TimelineManager:
			timeline_manager = candidate as TimelineManager
		if player_combat_data == null and candidate is PlayerCombatData:
			player_combat_data = candidate as PlayerCombatData
		if timeline_manager != null and player_combat_data != null:
			break

	# 验证管理器是否成功获取
	if timeline_manager == null:
		push_error("TimeLine：找不到 TimelineManager。")
		return
	if player_combat_data == null:
		push_error("TimeLine：找不到 PlayerCombatData。")
		return

	# 集中连接所有相关的全局和局部信号并执行首次刷新
	_connect_timeline_signals()
	_connect_card_signals()
	_connect_resource_signals()
	_rebuild_timeline()

# 连接时间轴管理器相关的核心流程信号
func _connect_timeline_signals() -> void:
	# 绑定时间轴变动与动画推进请求信号
	if not timeline_manager.timeline_changed.is_connected(_on_timeline_changed):
		timeline_manager.timeline_changed.connect(_on_timeline_changed)
	if not timeline_manager.time_visual_move_requested.is_connected(_on_time_visual_move_requested):
		timeline_manager.time_visual_move_requested.connect(_on_time_visual_move_requested)
	
	# 绑定行动结算的开始与结束信号
	if not timeline_manager.action_resolution_started.is_connected(_on_action_resolution_started):
		timeline_manager.action_resolution_started.connect(_on_action_resolution_started)
	if not timeline_manager.action_resolved.is_connected(_on_action_resolved):
		timeline_manager.action_resolved.connect(_on_action_resolved)
	
	# 绑定时间推进完成信号
	if not timeline_manager.time_advance_finished.is_connected(_on_time_advance_finished):
		timeline_manager.time_advance_finished.connect(_on_time_advance_finished)

# 连接卡牌预览相关的全局总线信号
func _connect_card_signals() -> void:
	# 绑定卡牌悬停预览、取消预览和确认打出信号
	BattleBus.card_timeline_preview_requested.connect(_on_card_timeline_preview_requested)
	BattleBus.card_timeline_preview_cleared.connect(_on_card_timeline_preview_cleared)
	BattleBus.card_timeline_preview_committed.connect(_on_card_timeline_preview_committed)

# 连接玩家资源（体力、法力）变化的全局总线信号
func _connect_resource_signals() -> void:
	# 绑定体力与法力变更信号以刷新资源图标
	if not BattleBus.player_stamina_changed.is_connected(_on_player_resource_changed):
		BattleBus.player_stamina_changed.connect(_on_player_resource_changed)
	if not BattleBus.player_mana_changed.is_connected(_on_player_resource_changed):
		BattleBus.player_mana_changed.connect(_on_player_resource_changed)

# 响应时间轴数据变动事件，触发视图重建
func _on_timeline_changed(_actions: Array[TimelineAction], _current_time: int) -> void:
	# 直接调用全量刷新方法
	_rebuild_timeline()

# 响应玩家资源变动事件，触发视图重建
func _on_player_resource_changed(_current_value: int, _max_value: int) -> void:
	# 直接调用全量刷新方法
	_rebuild_timeline()

# 响应容器尺寸改变事件，延迟触发视图重建
func _on_timeline_resized() -> void:
	# 使用延迟调用避免布局计算中的冲突
	call_deferred("_rebuild_timeline")

# 全量重建并刷新时间轴上的所有标记和视觉状态
func _rebuild_timeline() -> void:
	# 拦截依赖缺失或UI不可用的情况
	if timeline_manager == null or player_combat_data == null or timeline_line.size.x <= 0.0:
		return

	# 同步敌方行动与资源恢复的标记图标
	_sync_enemy_action_markers()
	_sync_resource_markers()

	# 刷新预测条视觉表现和悬停详情列表
	_refresh_preview_visuals(false)
	_refresh_detail_list()

# 同步敌方行动图标的位置与层叠状态，清理过期图标
func _sync_enemy_action_markers() -> void:
	# 获取当前范围内的可见行动并初始化去重字典
	var visible_actions := timeline_manager.get_visible_actions(VISIBLE_RANGE)
	var live_sequence_ids: Dictionary = {}
	var stack_counts: Dictionary = {}

	# 遍历行动数据并更新图标位置与元数据
	for action: TimelineAction in visible_actions:
		if action == null or action.actor_side != TimelineAction.ActorSide.ENEMY:
			continue

		var remaining_time := action.execute_time - timeline_manager.current_time
		if remaining_time < 0 or remaining_time > VISIBLE_RANGE:
			continue

		var sequence_id := action.sequence_id
		live_sequence_ids[sequence_id] = true
		
		var marker := _get_enemy_marker(sequence_id)
		if marker == null:
			marker = _create_enemy_action_marker(action)
			enemy_markers[sequence_id] = marker

		var stack_index := int(stack_counts.get(action.execute_time, 0))
		stack_counts[action.execute_time] = stack_index + 1
		var base_y := _get_line_center_y() - enemy_stack_gap * float(stack_index)

		marker.set_meta("action", action)
		marker.set_meta("absolute_time", float(action.execute_time))
		marker.set_meta("remaining_time", float(remaining_time))
		marker.set_meta("base_y", base_y)

		var marker_x := _remaining_time_to_x(float(remaining_time))
		if active_enemy_action != null and active_enemy_action.sequence_id == sequence_id:
			marker_x = timeline_line.position.x
		
		marker.position = Vector2(marker_x, base_y)
		_update_marker_scale(marker, false)

	# 遍历缓存清理不再可见的过期敌方图标
	var marker_keys := enemy_markers.keys().duplicate()
	for raw_sequence_id in marker_keys:
		var sequence_id := int(raw_sequence_id)
		if live_sequence_ids.has(sequence_id):
			continue
		if active_enemy_action != null and active_enemy_action.sequence_id == sequence_id:
			continue
		_remove_enemy_marker_immediately(sequence_id)

# 根据敌方行动数据创建一个新的标记UI组件
func _create_enemy_action_marker(action: TimelineAction) -> Control:
	# 获取行动分类以决定使用矩形还是三角形图标
	var category := _get_enemy_action_category(action)
	var visual_name := "Rectangle" if category == "skill" else "Triangle"

	# 实例化基础图标组件
	var marker := _create_marker(visual_name, Color.WHITE)
	if marker == null:
		return null

	# 为实例化的图标添加鼠标悬停检测区域
	_create_enemy_hover_area(marker, action)
	return marker

# 尝试从行动字典或负载中获取行动的类别
func _get_enemy_action_category(action: TimelineAction) -> String:
	# 优先从 action.payload 中获取类别
	var category := str(action.payload.get("category", ""))
	if category != "":
		return category

	# 降级从 action_data 中获取类别
	var action_data := _get_action_data(action)
	return str(action_data.get("category", ""))

# 通过序列号从缓存中安全获取敌方行动图标
func _get_enemy_marker(sequence_id: int) -> Control:
	# 使用 get 方法防崩并在返回前进行类型转换
	return enemy_markers.get(sequence_id, null) as Control

# 立即移除指定的敌方图标并处理悬停状态的清理
func _remove_enemy_marker_immediately(sequence_id: int) -> void:
	# 验证图标是否存在，不存在则直接清除字典键
	var marker := _get_enemy_marker(sequence_id)
	if marker == null:
		enemy_markers.erase(sequence_id)
		return

	# 检查并清除当前悬停状态以防空指针
	var action_variant = marker.get_meta("action", null)
	if hovered_enemy_action != null and action_variant == hovered_enemy_action:
		hovered_enemy_action = null

	# 清理字典缓存并释放节点内存，随后刷新详情列表
	enemy_markers.erase(sequence_id)
	marker.queue_free()
	_refresh_detail_list()

# 同步资源恢复图标的位置与堆叠状态，清理过期图标
func _sync_resource_markers() -> void:
	# 获取可见范围内的资源恢复预览事件
	var recovery_events := player_combat_data.get_resource_recovery_preview(VISIBLE_RANGE)
	var live_keys: Dictionary = {}
	var stack_counts: Dictionary = {}

	# 遍历事件生成唯一键并更新资源图标位置
	for event: Dictionary in recovery_events:
		var remaining_time := float(event.get("remaining_time", -1.0))
		if remaining_time < 0.0 or remaining_time > float(VISIBLE_RANGE) + 0.001:
			continue

		var resource_type := str(event.get("resource_type", ""))
		var marker_color := Color.WHITE
		match resource_type:
			"stamina": marker_color = stamina_marker_color
			"mana": marker_color = mana_marker_color
			_: continue

		var absolute_time := float(timeline_manager.current_time) + remaining_time
		var resource_key := "%s:%.3f" % [resource_type, absolute_time]
		live_keys[resource_key] = true

		var marker := resource_markers.get(resource_key, null) as Control
		if marker == null:
			marker = _create_marker("Circle", marker_color)
			if marker == null:
				push_error("TimeLine：资源恢复图标创建失败，resource_key=%s。" % resource_key)
				continue
			resource_markers[resource_key] = marker

		var stack_key := roundi(absolute_time * 1000.0)
		var stack_index := int(stack_counts.get(stack_key, 0))
		stack_counts[stack_key] = stack_index + 1
		var base_y := _get_line_center_y() + resource_stack_gap * float(stack_index)

		marker.set_meta("absolute_time", absolute_time)
		marker.set_meta("remaining_time", remaining_time)
		marker.set_meta("base_y", base_y)
		marker.position = Vector2(_remaining_time_to_x(remaining_time), base_y)
		_update_marker_scale(marker, false)

	# 清理在当前范围内不再有效的资源图标
	var resource_keys := resource_markers.keys().duplicate()
	for raw_key in resource_keys:
		var key := str(raw_key)
		if live_keys.has(key):
			continue
		var marker := resource_markers.get(key, null) as Control
		resource_markers.erase(key)
		if marker != null:
			marker.queue_free()

# 实例化通用标记节点并根据传入参数设置颜色和形状
func _create_marker(selected_visual_name: String, marker_color: Color) -> Control:
	# 校验预制体并实例化标记节点
	if action_marker_scene == null:
		push_error("TimeLine：没有绑定 actions.tscn。")
		return null
	var marker := action_marker_scene.instantiate() as Control
	if marker == null:
		push_error("TimeLine：actions.tscn 根节点不是 Control。")
		return null

	# 初始化节点基础属性并添加到槽位中
	action_slot.add_child(marker)
	marker.scale = Vector2.ONE
	marker.modulate = Color.WHITE
	marker.z_index = 2
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 遍历子形状节点控制显隐状态
	for visual_name: String in ["Circle", "Triangle", "Rectangle"]:
		var visual := marker.get_node_or_null(visual_name) as TextureRect
		if visual == null:
			continue
		visual.visible = (visual_name == selected_visual_name)
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 对选中的形状节点应用目标颜色
	var selected_visual := marker.get_node_or_null(selected_visual_name) as TextureRect
	if selected_visual != null:
		selected_visual.self_modulate = marker_color

	return marker

# 为标记图标动态创建一个拦截鼠标交互的隐形区域
func _create_enemy_hover_area(marker: Control, action: TimelineAction) -> void:
	# 创建透明控件并设置尺寸位置
	var hover_area := Control.new()
	hover_area.name = "HoverArea"
	hover_area.position = Vector2(-15.0, -30.0)
	hover_area.size = Vector2(30.0, 32.0)
	hover_area.mouse_filter = Control.MOUSE_FILTER_STOP
	hover_area.z_index = 20
	marker.add_child(hover_area)

	# 绑定鼠标移入移出信号以处理悬停逻辑
	hover_area.mouse_entered.connect(_on_enemy_marker_mouse_entered.bind(action))
	hover_area.mouse_exited.connect(_on_enemy_marker_mouse_exited.bind(action))

# 执行时间推进时的图标与预览条平滑移动动画
func _on_time_visual_move_requested(from_time: int, to_time: int) -> void:
	# 校验关键节点状态，缺失时立即结束逻辑等待防卡死
	if timeline_manager == null:
		push_error("TimeLine：收到移动请求时，timeline_manager 仍然为空。")
		return
	if timeline_line == null or action_slot == null or card_time_preview == null:
		push_error("TimeLine：缺少关键UI节点，无法播放移动动画。")
		timeline_manager.finish_time_visual_move()
		return

	# 计算推进差值和限制动画播放时长
	var elapsed_time := maxi(to_time - from_time, 0)
	if elapsed_time <= 0:
		timeline_manager.finish_time_visual_move()
		return
	var duration := clampf(float(elapsed_time) / 10.0 * move_duration_per_10_time, minimum_move_duration, maximum_move_duration)

	# 获取所有图标快照并建立补间动画以平滑过渡
	var markers: Array[Control] = _get_all_markers()
	var tween := create_tween().set_parallel(true)
	var has_animation := false

	# 遍历图标计算终点坐标并追加位移动画
	for marker: Control in markers:
		if marker == null or not is_instance_valid(marker):
			continue
		var absolute_time := float(marker.get_meta("absolute_time", float(to_time)))
		var target_remaining := maxf(absolute_time - float(to_time), 0.0)
		var base_y := float(marker.get_meta("base_y", marker.position.y))
		var target_position := Vector2(_remaining_time_to_x(target_remaining), base_y)
		tween.tween_property(marker, "position", target_position, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		has_animation = true

	# 计算并添加已确认预测条的动态收缩动画
	var target_committed_remaining := maxf(committed_preview_remaining - float(elapsed_time), 0.0)
	if committed_preview_remaining > 0.0:
		var target_width := timeline_line.size.x * minf(target_committed_remaining, float(VISIBLE_RANGE)) / float(VISIBLE_RANGE)
		var preview_target_size := Vector2(target_width, maxf(preview_line_height, timeline_line.size.y))
		card_time_preview.visible = true
		tween.tween_property(card_time_preview, "size", preview_target_size, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		has_animation = true

	# 等待所有动画执行完成
	if has_animation:
		await tween.finished

	# 更新内部时间记录状态
	committed_preview_remaining = target_committed_remaining
	for marker: Control in markers:
		if marker == null or not is_instance_valid(marker):
			continue
		var absolute_time := float(marker.get_meta("absolute_time", float(to_time)))
		marker.set_meta("remaining_time", maxf(absolute_time - float(to_time), 0.0))

	# 刷新图标层级表现并通知逻辑层动画结束
	_refresh_preview_visuals(false)
	if timeline_manager != null and is_instance_valid(timeline_manager):
		timeline_manager.finish_time_visual_move()

# 将所有敌方与资源图标对象聚合并返回为一个数组
func _get_all_markers() -> Array[Control]:
	# 遍历字典提取所有有效的Control节点
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

# 当敌人行动开始结算时，将其图标放大并锁定在原点
func _on_action_resolution_started(action: TimelineAction) -> void:
	# 校验行动有效性与所属阵营
	if action == null or action.actor_side != TimelineAction.ActorSide.ENEMY:
		return

	# 设置活跃状态并尝试获取或创建图标实例
	active_enemy_action = action
	var marker := _get_enemy_marker(action.sequence_id)
	if marker == null:
		marker = _create_enemy_action_marker(action)
		if marker == null:
			push_error("TimeLine：当前行动图标创建失败，sequence_id=%d。" % action.sequence_id)
			active_enemy_action = null
			return
		enemy_markers[action.sequence_id] = marker

	# 重写图标元数据并重置表现位置与层叠层级
	marker.set_meta("action", action)
	marker.set_meta("absolute_time", float(action.execute_time))
	marker.set_meta("remaining_time", 0.0)
	marker.set_meta("base_y", _get_line_center_y())
	marker.position.x = timeline_line.position.x
	marker.z_index = 8
	
	# 执行缩放高亮状态更新
	_update_marker_scale(marker, true)

# 当敌人行动结算结束时，淡出并销毁该图标
func _on_action_resolved(action: TimelineAction) -> void:
	# 校验行动有效性与所属阵营
	if action == null or action.actor_side != TimelineAction.ActorSide.ENEMY:
		return

	# 清理活跃状态和悬停记录并刷新面板
	var marker := _get_enemy_marker(action.sequence_id)
	if hovered_enemy_action != null and hovered_enemy_action.sequence_id == action.sequence_id:
		hovered_enemy_action = null
	active_enemy_action = null
	_refresh_detail_list()

	# 找不到图标则直接从字典中移除
	if marker == null:
		enemy_markers.erase(action.sequence_id)
		return

	# 创建并播放渐隐消失动画
	var tween := marker.create_tween()
	tween.set_parallel(true)
	tween.tween_property(marker, "scale", Vector2.ONE * 0.75, 0.12)
	tween.tween_property(marker, "modulate:a", 0.0, 0.12)
	await tween.finished

	# 清理字典引用并安全释放节点
	enemy_markers.erase(action.sequence_id)
	if is_instance_valid(marker):
		marker.queue_free()

# 处理卡牌悬停时触发的时间预测条显示逻辑
func _on_card_timeline_preview_requested(card_node: Control, time_cost: int) -> void:
	# 记录悬停卡牌实例及预期耗时并重绘界面
	if card_node == null:
		return
	hover_preview_source = card_node
	hover_preview_time = maxi(time_cost, 0)
	_refresh_preview_visuals(true)
	_refresh_detail_list()

# 处理卡牌取消悬停时预测条的隐藏逻辑
func _on_card_timeline_preview_cleared(card_node: Control) -> void:
	# 验证卡牌一致性后清除预测状态
	if hover_preview_source != card_node:
		return
	hover_preview_source = null
	hover_preview_time = 0
	_refresh_preview_visuals(true)
	_refresh_detail_list()

# 处理卡牌确认打出后，预测时间锁定为正式消耗时间的逻辑
func _on_card_timeline_preview_committed(time_cost: int) -> void:
	# 将预期耗时转换为已提交时间并清空悬停态
	committed_preview_remaining = float(maxi(time_cost, 0))
	hover_preview_source = null
	hover_preview_time = 0
	_refresh_preview_visuals(false)
	_refresh_detail_list()

# 当时间推进逻辑彻底结束后重置相关预览变量
func _on_time_advance_finished(_current_time: int) -> void:
	# 清空确认预测时间并重绘画布
	committed_preview_remaining = 0.0
	_refresh_preview_visuals(true)
	_refresh_detail_list()

# 根据已确认消耗或卡牌悬停状态，计算最终生效的预览时间跨度
func _get_effective_preview_time() -> float:
	# 优先返回已确认生效的时间
	if committed_preview_remaining > 0.0:
		return committed_preview_remaining
	# 降级返回有效节点悬停所产生的耗时
	if hover_preview_source != null and is_instance_valid(hover_preview_source):
		return float(hover_preview_time)
	return 0.0

# 依据有效的预览时间更新背景条宽度和影响范围内的图标缩放
func _refresh_preview_visuals(animate: bool) -> void:
	# 计算预览时间，若无时间则隐藏条块并重置图标
	var effective_preview_time := _get_effective_preview_time()
	if effective_preview_time <= 0.0:
		card_time_preview.visible = false
		for marker: Control in _get_all_markers():
			_update_marker_scale(marker, animate)
		return

	# 计算并设置预览条的目标尺寸与位置
	var visible_preview_time := minf(effective_preview_time, float(VISIBLE_RANGE))
	var preview_height := maxf(preview_line_height, timeline_line.size.y)
	card_time_preview.visible = true
	card_time_preview.position = Vector2(timeline_line.position.x, _get_line_center_y() - preview_height * 0.5)
	var target_size := Vector2(timeline_line.size.x * visible_preview_time / float(VISIBLE_RANGE), preview_height)

	# 附带动画过渡或直接应用新尺寸
	if animate:
		var tween := card_time_preview.create_tween()
		tween.tween_property(card_time_preview, "size", target_size, scale_animation_duration)
	else:
		card_time_preview.size = target_size

	# 遍历更新所有图标的状态
	for marker: Control in _get_all_markers():
		_update_marker_scale(marker, animate)

# 动态调整目标图标的缩放大小以表现当前执行中或处于预览范围内
func _update_marker_scale(marker: Control, animate: bool) -> void:
	# 节点合法性检查
	if marker == null or not is_instance_valid(marker):
		return

	# 提取图标内置行动信息以进行状态判定
	var target_scale := Vector2.ONE
	var action_variant = null
	if marker.has_meta(&"action"):
		action_variant = marker.get_meta(&"action")

	# 根据执行状态或所处预览时间区间赋予不同倍率
	if active_enemy_action != null and action_variant == active_enemy_action:
		target_scale *= active_action_scale
	else:
		var effective_preview_time := _get_effective_preview_time()
		var remaining_time := 999999.0
		if marker.has_meta(&"remaining_time"):
			remaining_time = float(marker.get_meta(&"remaining_time"))
		if effective_preview_time > 0.0 and remaining_time <= effective_preview_time + 0.001:
			target_scale *= preview_highlight_scale

	# 结束残余的旧缩放动画以防冲突
	if marker.has_meta(&"scale_tween"):
		var old_tween_variant = marker.get_meta(&"scale_tween")
		if old_tween_variant is Tween:
			var old_tween := old_tween_variant as Tween
			if old_tween.is_valid():
				old_tween.kill()

	# 直接赋值或建立新的缩放补间动画
	if not animate:
		marker.scale = target_scale
		return
	var tween := marker.create_tween()
	tween.tween_property(marker, "scale", target_scale, scale_animation_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	marker.set_meta(&"scale_tween", tween)

# 鼠标移入敌方图标时注册悬停行为以触发详情展示
func _on_enemy_marker_mouse_entered(action: TimelineAction) -> void:
	# 验证非空并重绘详情
	if action == null:
		return
	hovered_enemy_action = action
	_refresh_detail_list()

# 鼠标移出敌方图标时注销悬停行为以取消详情展示
func _on_enemy_marker_mouse_exited(action: TimelineAction) -> void:
	# 确保移出对象匹配后重绘详情
	if hovered_enemy_action != action:
		return
	hovered_enemy_action = null
	_refresh_detail_list()

# 负责重构UI面板中用于描述悬停行动或卡牌作用范围内的所有文本
func _refresh_detail_list() -> void:
	# 清空现有子节点列表数据
	_clear_detail_list()
	var detail_lines: Array[String] = []

	# 根据不同交互状态（单选/悬停范围）聚合需要展现的行动文本
	if hovered_enemy_action != null:
		detail_lines.append(_format_enemy_action_detail(hovered_enemy_action))
	elif hover_preview_source != null and is_instance_valid(hover_preview_source) and hover_preview_time > 0 and committed_preview_remaining <= 0.0:
		var actions := timeline_manager.get_visible_actions(VISIBLE_RANGE)
		for action: TimelineAction in actions:
			if action == null or action.actor_side != TimelineAction.ActorSide.ENEMY:
				continue
			var remaining_time := action.execute_time - timeline_manager.current_time
			if remaining_time < 0 or remaining_time > hover_preview_time:
				continue
			detail_lines.append(_format_enemy_action_detail(action))
		if detail_lines.is_empty():
			detail_lines.append("推进范围内无敌方行动")

	# 根据聚合结果决定隐藏面板或生成Label展示文本
	if detail_lines.is_empty():
		detail_list.visible = false
		return
	for detail_text: String in detail_lines:
		var label := Label.new()
		label.text = detail_text
		label.custom_minimum_size = Vector2(420.0, 0.0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		detail_list.add_child(label)
	detail_list.visible = true

# 将详情列表内所有的子节点移出场景树并释放内存
func _clear_detail_list() -> void:
	# 遍历销毁并脱离父级关联
	for child in detail_list.get_children():
		detail_list.remove_child(child)
		child.queue_free()

# 根据行动字典数据拼装敌方行动效果描述字符串
func _format_enemy_action_detail(action: TimelineAction) -> String:
	# 获取底层信息及配置名称
	var action_data := _get_action_data(action)
	var action_name := str(action_data.get("name", action.action_name))

	# 若存在硬编码描述则直接组装返回
	var explicit_description := str(action_data.get("description", ""))
	if explicit_description != "":
		return "%s - %s" % [tr(action_name), tr(explicit_description)]

	# 解析攻击或Buff等特性并进行数值格式化
	var effect_type := str(action_data.get("effect_type", action.payload.get("effect_type", "")))
	var effect_description := ""
	match effect_type:
		"damage":
			var damage := int(action_data.get("damage", 0))
			effect_description = "造成 %d 点伤害" % damage
		"multi_damage":
			var hit_count := int(action_data.get("hit_count", 1))
			var damage_per_hit := int(action_data.get("damage_per_hit", 0))
			effect_description = "连续攻击 %d 次，每次 %d 点伤害" % [hit_count, damage_per_hit]
		"dodge_buff":
			var dodge_bonus := float(action_data.get("dodge_bonus", 0.0))
			var duration := int(action_data.get("duration", 0))
			effect_description = "闪避率提高 %d%%，持续 %d 时间" % [roundi(dodge_bonus * 100.0), duration]
		"block_next_attack":
			var charges := int(action_data.get("charges", 1))
			var duration := int(action_data.get("duration", 0))
			effect_description = "格挡接下来 %d 次攻击，持续 %d 时间" % [charges, duration]
		"rebirth_charge":
			var charge_amount := int(action_data.get("charge_amount", 1))
			effect_description = "获得 %d 层重生充能" % charge_amount
		_:
			effect_description = "效果类型：%s" % effect_type

	# 将格式化后的特征信息与技能名拼装并返回
	return "%s - %s" % [tr(action_name), effect_description]

# 提取TimelineAction内置的负载字典以防止取值报错
func _get_action_data(action: TimelineAction) -> Dictionary:
	# 类型校验后返回行动附加数据
	if action == null:
		return {}
	var action_data_variant = action.payload.get("action_data", {})
	if typeof(action_data_variant) != TYPE_DICTIONARY:
		return {}
	return action_data_variant as Dictionary

# 把剩余时间转换成主界面的X轴相对像素坐标
func _remaining_time_to_x(remaining_time: float) -> float:
	# 映射时间比例到推进轴长度
	var ratio := clampf(remaining_time / float(VISIBLE_RANGE), 0.0, 1.0)
	return timeline_line.position.x + timeline_line.size.x * ratio

# 获取时间轴背板垂直中心位置坐标
func _get_line_center_y() -> float:
	# Y偏移量与高度一半相加
	return timeline_line.position.y + timeline_line.size.y * 0.5
