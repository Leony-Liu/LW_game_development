## 播放短暂的玩家受伤镜头位移和红色屏幕闪烁。
## 独立于行走晃动与玩家运动，效果结束后恢复局部变换。
class_name PlayerDamageFeedback
extends Node

@export var shake_pivot: Node3D
@export var flash_rect: ColorRect
@export_range(0.0, 0.2, 0.005) var shake_distance: float = 0.045
@export_range(0.05, 1.0, 0.01) var shake_duration: float = 0.24
@export var flash_color: Color = Color(0.85, 0.04, 0.04, 0.28)
@export_range(0.05, 1.0, 0.01) var flash_duration: float = 0.3

var _base_transform: Transform3D
var _is_configured: bool = false
var _shake_tween: Tween
var _flash_tween: Tween
var _shake_finished: bool = true
var _flash_finished: bool = true
var _completion: Callable


# 保存相机基准位置并使全屏层初始透明且不拦截输入。
func _ready() -> void:
	if shake_pivot == null or flash_rect == null:
		push_warning("PlayerDamageFeedback ： Missing optional camera pivot or flash rect; damage feedback is disabled")
		return
	_base_transform = shake_pivot.transform
	flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_configured = true


# 重复伤害会重新播放同一组效果，不叠加 Tween 或位移。
func play_damage(on_completed: Callable = Callable()) -> bool:
	if not _is_configured or not is_instance_valid(shake_pivot) or not is_instance_valid(flash_rect):
		return false
	cancel_feedback()
	_completion = on_completed
	_shake_finished = false
	_flash_finished = false
	_shake_tween = create_tween()
	_shake_tween.tween_property(shake_pivot, "position", _base_transform.origin + Vector3(shake_distance, 0.0, 0.0), shake_duration * 0.25)
	_shake_tween.tween_property(shake_pivot, "position", _base_transform.origin + Vector3(-shake_distance, 0.0, 0.0), shake_duration * 0.35)
	_shake_tween.tween_property(shake_pivot, "position", _base_transform.origin, shake_duration * 0.4)
	_shake_tween.finished.connect(_on_shake_finished.bind(_shake_tween))
	flash_rect.color = flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash_rect, "color:a", 0.0, flash_duration)
	_flash_tween.finished.connect(_on_flash_finished.bind(_flash_tween))
	return true


# 模式切换及释放时恢复镜头与屏幕状态。
func cancel_feedback() -> void:
	var completed_callback := _completion
	_completion = Callable()
	if _shake_tween != null and _shake_tween.is_running():
		_shake_tween.kill()
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	_shake_tween = null
	_flash_tween = null
	_shake_finished = true
	_flash_finished = true
	if _is_configured and is_instance_valid(shake_pivot):
		shake_pivot.transform = _base_transform
	if _is_configured and is_instance_valid(flash_rect):
		flash_rect.color.a = 0.0
	if completed_callback.is_valid():
		completed_callback.call_deferred()


# 相机与屏幕层分别完成，最后一个结束时才回报整个受伤表现。
func _on_shake_finished(finished_tween: Tween) -> void:
	if finished_tween != _shake_tween:
		return
	_shake_tween = null
	_shake_finished = true
	if is_instance_valid(shake_pivot):
		shake_pivot.transform = _base_transform
	_try_finish_damage()


# 屏幕层透明后才允许与相机完成结果合并。
func _on_flash_finished(finished_tween: Tween) -> void:
	if finished_tween != _flash_tween:
		return
	_flash_tween = null
	_flash_finished = true
	if is_instance_valid(flash_rect):
		flash_rect.color.a = 0.0
	_try_finish_damage()


# 两个并行 Tween 都结束后仅回调一次。
func _try_finish_damage() -> void:
	if not _shake_finished or not _flash_finished:
		return
	var completed_callback := _completion
	_completion = Callable()
	if completed_callback.is_valid():
		completed_callback.call_deferred()


# 场景释放时终止两个 Tween。
func _exit_tree() -> void:
	cancel_feedback()
