## 只驱动敌人模型的临时攻击与受击表现。
## 模型运动不改变房间中的敌人根节点或战斗数据。
class_name EnemyVisual
extends Node3D

@export var model: Node3D
@export_range(0.0, 0.5, 0.01) var hit_offset: float = 0.09
@export_range(0.0, 0.5, 0.01) var lunge_distance: float = 0.2
@export_range(0.05, 0.5, 0.01) var motion_duration: float = 0.22

var _base_transform: Transform3D
var _motion_tween: Tween
var _completion: Callable


# 捕获可视模型的原始局部变换。
func _ready() -> void:
	if model == null:
		push_warning("EnemyVisual ： No model assigned; combat motion is disabled")
		return
	_base_transform = model.transform


# 每次受击替换旧运动，并回到模型原始局部位置。
func play_hit_reaction(on_completed: Callable = Callable()) -> bool:
	if not is_instance_valid(model):
		return false
	_stop_motion()
	_completion = on_completed
	_motion_tween = create_tween()
	_motion_tween.tween_property(model, "position", _base_transform.origin + Vector3(hit_offset, 0.0, 0.0), motion_duration * 0.35)
	_motion_tween.tween_property(model, "position", _base_transform.origin, motion_duration * 0.65)
	_motion_tween.finished.connect(_on_motion_finished.bind(_motion_tween))
	return true


# 按当前玩家方向推动模型，不移动敌人定位根节点。
func play_attack_lunge(target_global_position: Vector3, on_completed: Callable = Callable()) -> bool:
	if not is_instance_valid(model):
		return false
	_stop_motion()
	_completion = on_completed
	var local_direction := global_transform.basis.inverse() * (target_global_position - global_position)
	local_direction.y = 0.0
	if local_direction.length_squared() < 0.0001:
		local_direction = Vector3.FORWARD
	local_direction = local_direction.normalized()
	_motion_tween = create_tween()
	_motion_tween.tween_property(model, "position", _base_transform.origin + local_direction * lunge_distance, motion_duration * 0.4)
	_motion_tween.tween_property(model, "position", _base_transform.origin, motion_duration * 0.6)
	_motion_tween.finished.connect(_on_motion_finished.bind(_motion_tween))
	return true


# 战斗结束、场景移除或新效果覆盖时清理偏移。
func cancel_feedback() -> void:
	_stop_motion()


# 停止旧 Tween 并恢复模型原位。
func _stop_motion() -> void:
	var completed_callback := _completion
	_completion = Callable()
	if _motion_tween != null and _motion_tween.is_running():
		_motion_tween.kill()
	_motion_tween = null
	if is_instance_valid(model):
		model.transform = _base_transform
	if completed_callback.is_valid():
		completed_callback.call_deferred()


# 仅接纳当前 Tween 的完成通知，避免旧效果释放新行动。
func _on_motion_finished(finished_tween: Tween) -> void:
	if finished_tween == _motion_tween:
		_stop_motion()


# 房间移除模型时终止在途运动。
func _exit_tree() -> void:
	_stop_motion()
