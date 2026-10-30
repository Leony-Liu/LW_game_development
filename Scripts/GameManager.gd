## 协调主菜单、基地与新远征之间的应用级流程。
## 先完成玩家数据保存，再提交场景切换；不保存远征运行时状态。
extends Node

const WeaponInstance = preload("res://Scripts/RefCounted/WeaponInstance.gd")
const BASE_SCENE_PATH: String = "res://BaseSystem/Base.tscn"
const EXPEDITION_SCENE_PATH: String = "res://ExpeditionSystem/ExpeditionSystem.tscn"
@export var new_game_config: Resource = preload("res://Scripts/NewGame.tres")

var _transition_in_progress: bool = false

# 供场景内临时 UI 避开应用已经提交的场景切换。
func is_scene_transition_pending() -> bool:
	return _transition_in_progress


# Editor 直接运行远征也完成同一存档交接，不再留下未注入的场景。
func _ready() -> void:
	_bootstrap_direct_expedition.call_deferred()


# 等主场景入树后，只处理没有应用层注入的直接远征入口。
func _bootstrap_direct_expedition() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != EXPEDITION_SCENE_PATH:
		return
	if not _ensure_player_weapon() or not _prepare_expedition(scene) or not PlayerSaveManager.save_with_expedition_marker(true):
		push_error("[GameManager] 直接远征初始化失败；保留原存档并停用探索。")
		var coordinator := scene.get_node_or_null("ExpeditionManager")
		if coordinator != null:
			coordinator.clear_player_data()
		var world := scene.get_node_or_null("WorldSystem")
		if world != null:
			world.player_visual.suspend_after_world_initialization_failure()


# 新游戏选择属于应用配置，既有武器绝不按起始数组重置。
func _ensure_player_weapon() -> bool:
	if not PlayerSaveManager.ensure_loaded():
		return false
	if PlayerSaveManager.get_current_weapon() != null:
		return true
	if new_game_config == null:
		push_error("[GameManager] 缺少必需的新游戏配置。")
		return false
	var weapon := AllWeaponData.get_weapon(new_game_config.initial_weapon_id)
	if weapon == null:
		push_error("[GameManager] 新游戏武器 ID %d 无法解析。" % new_game_config.initial_weapon_id)
		return false
	return PlayerSaveManager.initialize_new_weapon(WeaponInstance.create_starting(weapon, AllCardData.get_cards()))


# 正常进入基地，中断恢复则直接进入全新远征。
func start_game() -> bool:
	if _transition_in_progress or not _ensure_player_weapon():
		return false
	if PlayerSaveManager.was_expedition_active():
		return start_expedition()
	var scene := _instantiate_scene(BASE_SCENE_PATH)
	return scene != null and _commit_transition(scene)


# 基地设施确认与中断恢复共用保存感知的远征入口。
func start_expedition() -> bool:
	if _transition_in_progress or not _ensure_player_weapon():
		return false
	var scene := _instantiate_scene(EXPEDITION_SCENE_PATH)
	if scene == null:
		return false
	if not _prepare_expedition(scene):
		scene.free()
		return false
	return _save_and_transition(scene, true)


# 应用只传递来源武器；远征数据模型自行创建独立副本。
func _prepare_expedition(scene: Node) -> bool:
	var coordinator := scene.get_node_or_null("ExpeditionManager")
	if coordinator == null:
		push_error("[GameManager] 远征准备失败：缺少 ExpeditionManager。")
		return false
	if not coordinator.initialize_player_data(PlayerSaveManager.get_current_weapon()):
		push_error("[GameManager] 远征准备失败：玩家武器独立副本初始化失败。")
		return false
	coordinator.death_confirmed.connect(_on_expedition_death_confirmed)
	coordinator.return_to_base_requested.connect(_on_expedition_return_requested)
	coordinator.extraction_requested.connect(_on_extraction_requested.bind(coordinator))
	return true


# 只接受当前远征处于探索阶段的请求，不允许从其他场景调用。
func return_to_base() -> bool:
	if not OS.is_debug_build() or _transition_in_progress:
		return false
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != EXPEDITION_SCENE_PATH:
		return false
	var coordinator := scene.get_node_or_null("ExpeditionManager")
	if coordinator == null or not coordinator.can_return_to_base():
		return false
	print("[GameManager] 开发调试返回：不执行撤离奖励结算。")
	return _return_to_base()


# 缺少真实资源模型与转换数据时明确拒绝，不保存假结算或清除恢复标记。
func _on_extraction_requested(operation_id: int, coordinator: Node) -> void:
	if not is_instance_valid(coordinator) or not coordinator.is_extraction_pending(operation_id):
		return
	var scene := get_tree().current_scene
	if _transition_in_progress or scene == null or scene.scene_file_path != EXPEDITION_SCENE_PATH or scene.get_node_or_null("ExpeditionManager") != coordinator:
		if not coordinator.reject_extraction(operation_id, "撤离未提交：场景或应用转换状态已失效。"):
			push_warning("[GameManager] 撤离失败通知已失效，保留当前终局状态。")
		return
	var reason := "撤离未完成：尚缺远征资源仓库、随身物资/魂、转换数据及长期资源结算存档。"
	if not coordinator.reject_extraction(operation_id, reason):
		return
	push_error("[GameManager] %s 保留远征、武器牌组和恢复标记，不执行保存或返回。" % reason)


# 监听者处理返回请求并检查结果，失败时保留当前远征供恢复或重试。
func _on_expedition_return_requested() -> void:
	if not return_to_base():
		push_error("[GameManager] 主动返回基地未提交；保留当前场景及可恢复的玩家数据。")


# 仅处理远征协调器发出的死亡确认通知，胜利仍由远征内部处理。
func _on_expedition_death_confirmed() -> void:
	if _transition_in_progress:
		return
	if not _return_to_base():
		push_error("[GameManager] 死亡确认后的返回未提交；保留当前场景供重试。")


# 主动返回与死亡确认复用同一保存、清标记和场景切换路径。
func _return_to_base() -> bool:
	var scene := _instantiate_scene(BASE_SCENE_PATH)
	return scene != null and _save_and_transition(scene, false)


# 准备场景先于保存，加载失败不会更改恢复标记。
func _instantiate_scene(path: String) -> Node:
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null or not packed.can_instantiate():
		push_error("[GameManager] 无法加载场景 %s；保留当前场景与恢复标记。" % path)
		return null
	return packed.instantiate()


# 只在保存成功后提交；切换失败则持久化回滚原标记。
func _save_and_transition(scene: Node, active: bool) -> bool:
	var previous := PlayerSaveManager.was_expedition_active()
	if not PlayerSaveManager.save_with_expedition_marker(active):
		push_error("[GameManager] 场景切换取消：玩家数据保存失败。")
		scene.free()
		return false
	if _commit_transition(scene):
		return true
	if not PlayerSaveManager.save_with_expedition_marker(previous):
		push_error("[GameManager] 场景未切换且恢复标记回滚写入失败；停止流程，请修复存储后重试。")
	return false


# 使用已配置但尚未入树的实例，保留原生 SceneTree 切换生命周期。
func _commit_transition(scene: Node) -> bool:
	_transition_in_progress = true
	var result := get_tree().change_scene_to_node(scene)
	if result != OK:
		_transition_in_progress = false
		push_error("[GameManager] 场景切换失败：%s。" % error_string(result))
		scene.free()
		return false
	get_tree().scene_changed.connect(_on_scene_changed, CONNECT_ONE_SHOT)
	return true


# 场景真正入树后再报告完成；鼠标由玩家表现组件管理。
func _on_scene_changed() -> void:
	_transition_in_progress = false
	if get_tree().current_scene != null:
		print("[GameManager] 场景切换完成：%s。" % get_tree().current_scene.scene_file_path)
