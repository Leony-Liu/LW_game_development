## 提供撤离设施的范围检测、提示和 E 交互意图。
## 可用性由 World 下发，不负责结算、保存或切换场景。
extends Node3D

signal interaction_requested

@export_group("交互配置")
@export var interaction_area: Area3D
@export var prompt_label: Label3D
@export var prompt_text: String = "按 E 撤离"

var _player: CharacterBody3D
var _interaction_enabled := false
var _status_message := ""

# 必需节点无效时停止交互，不创建替代检测区。
func _ready() -> void:
	if not validate_configuration():
		push_error("[ExtractionFacility] 初始化失败：缺少交互区域、球形检测体或提示引用。")
		set_process(false)
		set_process_unhandled_key_input(false)
		return
	prompt_label.hide()

# 场景装配方在接入事件前检查必需配置。
func validate_configuration() -> bool:
	if not is_instance_valid(interaction_area) or not is_instance_valid(prompt_label):
		return false
	var shape := interaction_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	return shape != null and shape.shape is SphereShape3D and not shape.disabled and shape.shape.radius > 0.0

# 仅接收拥有者提供的真实玩家和当前交互可用性。
func configure_interaction(player: CharacterBody3D, enabled: bool) -> void:
	_player = player
	_interaction_enabled = enabled
	_refresh_prompt()

# 每帧只读取本模块的 Area，不查询其他玩法系统。
func _process(_delta: float) -> void:
	_refresh_prompt()

# 沿用 E 动作；在门的 unhandled_input 之前消费已选中的设施交互。
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and event.is_action_pressed("interact") and request_interaction():
		get_viewport().set_input_as_handled()

# 返回是否发出意图，不读取监听者的结算结果。
func request_interaction() -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or not _interaction_enabled or not is_player_in_range(_player):
		return false
	_status_message = ""
	interaction_requested.emit()
	return true

# 指定玩家必须真实重叠，其他 CharacterBody 不授予撤离资格。
func is_player_in_range(player: CharacterBody3D) -> bool:
	return is_instance_valid(player) and is_instance_valid(interaction_area) and interaction_area.is_inside_tree() and interaction_area.overlaps_body(player)

# 只显示上层给出的失败原因，允许修复依赖后重新交互。
func show_status(message: String) -> void:
	_status_message = message
	_refresh_prompt()

# 出范围时清除旧提示，不锁定玩家或改变燃料。
func _refresh_prompt() -> void:
	if not is_instance_valid(prompt_label):
		return
	var nearby := is_player_in_range(_player)
	if not nearby:
		_status_message = ""
	prompt_label.visible = nearby and _interaction_enabled
	prompt_label.text = prompt_text if _status_message.is_empty() else _status_message + "\n" + prompt_text
