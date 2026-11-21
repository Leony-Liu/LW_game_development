## 提供工作台设施的指定玩家范围检测与交互意图。
## 不监听输入、不决定房间归属，也不持有界面或业务数据。
extends Node3D

signal interaction_requested

@export_group("交互配置")
@export var interaction_area: Area3D
@export var prompt_label: Label3D

var _player_ref: WeakRef
var _interaction_enabled := false


# 独立实例只验证自身配置，默认不授予交互资格。
func _ready() -> void:
	_refresh_prompt()
	if not validate_configuration():
		push_error("[CardWorkbenchFacility] 初始化失败：缺少有效的球形交互区域或提示引用。")
		_interaction_enabled = false


# 与既有设施共用零检测层、玩家层掩码及球形范围约定。
func validate_configuration() -> bool:
	if not is_instance_valid(interaction_area) or not is_instance_valid(prompt_label):
		return false
	var shape := interaction_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	return shape != null and shape.shape is SphereShape3D and shape.shape.radius > 0.0 and not shape.disabled and interaction_area.monitoring and interaction_area.collision_layer == 0 and interaction_area.collision_mask == 1


# 未来拥有者下发真实玩家与可用性；不自行查询世界或 UI。
func configure_interaction(player: CharacterBody3D, enabled: bool) -> bool:
	_player_ref = null
	_interaction_enabled = false
	_refresh_prompt()
	if not validate_configuration() or (enabled and not is_instance_valid(player)):
		push_error("[CardWorkbenchFacility] 交互配置失败：检测区域、提示或必需玩家无效；保持禁用。")
		return false
	_player_ref = weakref(player) if is_instance_valid(player) else null
	_interaction_enabled = enabled
	_refresh_prompt()
	return true

# 范围变化只刷新本设施提示，不监听任何按键。
func _process(_delta: float) -> void:
	_refresh_prompt()

# 启用状态由上层唯一目标仲裁下发。
func _refresh_prompt() -> void:
	if is_instance_valid(prompt_label):
		var player: CharacterBody3D = _player_ref.get_ref() if _player_ref != null else null
		prompt_label.visible = _interaction_enabled and is_inside_tree() and is_player_in_range(player)


# 只查询物理重叠，不用距离或任意附近物体代替真实玩家。
func is_player_in_range(player: CharacterBody3D) -> bool:
	return is_instance_valid(player) and is_instance_valid(interaction_area) and interaction_area.is_inside_tree() and interaction_area.overlaps_body(player)


# 接受仅表示发出意图；未来上层仍须校验房间与远征状态。
func request_interaction() -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or not _interaction_enabled:
		return false
	var player: CharacterBody3D = _player_ref.get_ref() if _player_ref != null else null
	if not is_player_in_range(player):
		return false
	interaction_requested.emit()
	return true


# 退出时释放注入上下文，重复实例不共享运行时状态。
func _exit_tree() -> void:
	_player_ref = null
	_interaction_enabled = false
	_refresh_prompt()
