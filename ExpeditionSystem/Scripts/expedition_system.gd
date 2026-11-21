## ExpeditionSystem 对应用层的唯一业务入口。
## 验证边界请求、委托内部 Manager，并转发已发生的通知。
class_name ExpeditionSystem
extends Node

signal death_confirmed
signal return_to_base_requested
signal extraction_requested(event: ExpeditionExtractionRequestedEvent)

var _expedition_manager: ExpeditionManager


# 首次调用可发生在入树前，只在本场景内解析并缓存 Manager。
func _ensure_manager() -> bool:
	if not is_instance_valid(_expedition_manager):
		_expedition_manager = get_node_or_null("ExpeditionManager") as ExpeditionManager
	return is_instance_valid(_expedition_manager)


# 场景装配时只连接一次内部通知。
func _ready() -> void:
	if not _ensure_manager():
		push_error("[ExpeditionSystem] 初始化失败：缺少必需的 ExpeditionManager。")
		return
	if not _expedition_manager.death_confirmed.is_connected(_on_death_confirmed):
		_expedition_manager.death_confirmed.connect(_on_death_confirmed)
	if not _expedition_manager.return_to_base_requested.is_connected(_on_return_to_base_requested):
		_expedition_manager.return_to_base_requested.connect(_on_return_to_base_requested)
	if not _expedition_manager.extraction_requested.is_connected(_on_extraction_requested):
		_expedition_manager.extraction_requested.connect(_on_extraction_requested)


# 释放缓存，不跨场景生命周期持有内部节点。
func _exit_tree() -> void:
	_expedition_manager = null


# 验证来源后委托 Manager 复制远征独立数据。
func initialize_player_data(request: ExpeditionInitializationRequest) -> ExpeditionInitializationResult:
	if request == null or request.source_weapon == null or not _ensure_manager():
		push_error("[ExpeditionSystem] 玩家数据初始化失败：请求或内部 Manager 无效。")
		return ExpeditionInitializationResult.new(false)
	return ExpeditionInitializationResult.new(_expedition_manager.initialize_player_data(request.source_weapon))


# 保持原有调试与探索门闩由 Manager 判定。
func can_return_to_base() -> bool:
	return _ensure_manager() and _expedition_manager.can_return_to_base()


# 查询当前操作身份，拒绝过期的撤离通知。
func is_extraction_pending(operation_id: int) -> bool:
	return _ensure_manager() and _expedition_manager.is_extraction_pending(operation_id)


# 将拒绝请求交给 Manager 的原有终局门闩。
func reject_extraction(request: ExpeditionExtractionRejectionRequest) -> bool:
	return request != null and _ensure_manager() and _expedition_manager.reject_extraction(request.operation_id, request.reason)


# 直接 Editor 初始化失败时停止探索并清理远征数据；可重复调用。
func abort_failed_initialization() -> void:
	if _ensure_manager():
		_expedition_manager.abort_failed_initialization()


# 转发死亡确认，不改变业务事实。
func _on_death_confirmed() -> void:
	death_confirmed.emit()


# 转发调试返回请求，应用层仍需自行校验。
func _on_return_to_base_requested() -> void:
	return_to_base_requested.emit()


# 保留撤离操作身份并包装为公开 Event。
func _on_extraction_requested(operation_id: int) -> void:
	extraction_requested.emit(ExpeditionExtractionRequestedEvent.new(operation_id))
