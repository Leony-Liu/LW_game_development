extends Node

# 用于遮挡全屏的纯黑转场矩形
var transition_rect: ColorRect
var is_transitioning: bool = false

func _ready() -> void:
	# 动态创建一个转场专用的 CanvasLayer
	# 层级设为 50：确保盖住 UILayer (10)，但处于 CRT 滤镜 (100) 之下
	var transition_layer = CanvasLayer.new()
	transition_layer.layer = 50
	add_child(transition_layer)
	
	transition_rect = ColorRect.new()
	transition_rect.color = Color.BLACK
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.modulate.a = 0.0 # 初始完全透明
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_rect)

# ==========================================
# 核心方法：播放转场动画并执行回调函数
# ==========================================
func transition_to(callback: Callable, duration: float = 0.3) -> void:
	if is_transitioning: return
	is_transitioning = true
	
	# 1. 拦截鼠标点击，防止转场期间玩家乱点 UI
	transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 2. 画面淡出变黑 (忽略时间缩放，防止被战斗慢动作卡住)
	var tween_out = create_tween().set_ignore_time_scale(true)
	tween_out.tween_property(transition_rect, "modulate:a", 1.0, duration)
	await tween_out.finished
	
	# 3. 【核心】画面全黑时，执行真正的场景替换逻辑
	if callback.is_valid():
		callback.call()
		
	# 4. 画面淡入变亮
	var tween_in = create_tween().set_ignore_time_scale(true)
	tween_in.tween_property(transition_rect, "modulate:a", 0.0, duration)
	await tween_in.finished
	
	# 5. 恢复鼠标交互
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
