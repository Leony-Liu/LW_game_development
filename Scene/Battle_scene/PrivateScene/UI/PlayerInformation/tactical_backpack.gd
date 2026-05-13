extends Control

@onready var item_container = $ItemContainer

var expanded_scale: Vector2 = Vector2(2.0, 2.0) # 展开放大的倍数
var collapsed_scale: Vector2 = Vector2(1.0, 1.0) # 默认收缩的倍数

var is_open: bool = false
var anim_tween: Tween

func _ready() -> void:
	# 1. 强制居中枢轴点
	item_container.pivot_offset = item_container.size / 2.0
	
	# 2. 【核心修复】等待 1 帧，让引擎彻底完成 UI 自适应排版，再计算位置
	await get_tree().process_frame
	
	# 3. 开局强制瞬移到右下角，防止任何闪烁
	_snap_to_corner()
	_set_buttons_interactable(false)

# 【核心功能】：监听玩家随时修改窗口大小或分辨率
func _notification(what: int) -> void:
	# 【修复Bug】：安全验证！如果节点还没加载完（开局瞬间），直接跳过，防止报空指针错！
	if not is_node_ready() or item_container == null:
		return
		
	if what == NOTIFICATION_RESIZED:
		# 窗口大小一旦改变，UI 自动修正坐标！
		if is_open:
			_snap_to_center()
		else:
			_snap_to_corner()
			
	# 失去焦点强制收回背包（防卡死Bug）
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_open:
			toggle_backpack(false)

func _process(_delta: float) -> void:
	var should_be_open = Input.is_action_pressed("open_backpack")
	
	if should_be_open and not is_open:
		toggle_backpack(true)
	elif not should_be_open and is_open:
		toggle_backpack(false)

func toggle_backpack(open: bool) -> void:
	is_open = open
	
	if anim_tween and anim_tween.is_valid():
		anim_tween.kill()
		
	anim_tween = create_tween().set_parallel(true)
	anim_tween.set_ignore_time_scale(true)
	
	# 动态获取目标的绝对坐标
	var target_pos = _get_center_pos() if is_open else _get_corner_pos()
	var target_scale = expanded_scale if is_open else collapsed_scale
	
	anim_tween.tween_property(item_container, "position", target_pos, 0.2)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	anim_tween.tween_property(item_container, "scale", target_scale, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
	if is_open:
		Engine.time_scale = 0.1 
		_set_buttons_interactable(true)
	else:
		Engine.time_scale = 1.0 
		_set_buttons_interactable(false)


# ==========================================
# 坐标计算雷达（绝对防偏移机制）
# ==========================================

# 1. 计算完美的中心坐标
func _get_center_pos() -> Vector2:
	# 自身尺寸(self.size)就是屏幕长宽。除以 2 就是屏幕正中心，减去枢轴点，100% 居中。
	return (self.size / 2.0) - item_container.pivot_offset

# 2. 计算右下角的安全坐标（防越界截断）
func _get_corner_pos() -> Vector2:
	var bottom_right_edge = self.size
	
	# 【防越界安全边距】：因为你的框是 250x250，中心到边缘是 125。
	# 这里必须填一个大于 125 的数！填 160 就意味着按钮离屏幕边缘还有 35 像素的安全距离。
	var safe_margin = Vector2(160, 160) 
	
	var target_center = bottom_right_edge - safe_margin
	return target_center - item_container.pivot_offset

# --- 瞬间移动（用于初始化和窗口变化修复） ---
func _snap_to_corner() -> void:
	item_container.position = _get_corner_pos()
	item_container.scale = collapsed_scale
	
func _snap_to_center() -> void:
	item_container.position = _get_center_pos()
	item_container.scale = expanded_scale


# ==========================================
# 交互与按钮
# ==========================================
func _set_buttons_interactable(can_click: bool) -> void:
	var filter_mode = Control.MOUSE_FILTER_STOP if can_click else Control.MOUSE_FILTER_IGNORE
	item_container.mouse_filter = filter_mode
	for child in item_container.get_children():
		if child is BaseButton:
			child.mouse_filter = filter_mode

func _on_btn_top_pressed() -> void:
	print("使用了上方的战术道具！")
func _on_btn_bottom_pressed() -> void:
	print("使用了下方的战术道具！")
