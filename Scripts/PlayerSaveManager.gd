## 协调玩家武器数据的恢复、保存及应用级交接。
## 武器与牌组归 WeaponInstance，新游戏选择由调用方配置。
extends Node

const PlayerCards = preload("res://Scripts/RefCounted/PlayerCardSaveModule.gd")
const WeaponInstance = preload("res://Scripts/RefCounted/WeaponInstance.gd")
@export var save_slot_id: String = "player_cards"
var _module: PlayerCards
var _registered: bool = false
var _loaded: bool = false

# 数据库初始化后注册模块，不在此选择或创建初始武器。
func _ready() -> void:
	_module = PlayerCards.new(AllCardData.get_cards(), AllWeaponData.get_weapons())
	_registered = SaveManager.register_module(_module)

# 恢复已有槽位；损坏或归属不明的数据拒绝覆盖。
func ensure_loaded() -> bool:
	if not _registered:
		push_error("[PlayerSaveManager] 玩家存档模块未注册。")
		return false
	if _loaded and SaveManager.current_slot_id == save_slot_id:
		return true
	_loaded = false
	if not SaveManager.current_slot_id.is_empty() and SaveManager.current_slot_id != save_slot_id:
		push_error("[PlayerSaveManager] 其他槽位已打开，拒绝覆盖。")
		return false
	if FileAccess.file_exists(SaveManager.SAVE_DIR + save_slot_id + ".json"):
		if not SaveManager.load_slot(save_slot_id):
			return false
	elif not SaveManager.create_new_save(save_slot_id, "Player weapons", false):
		return false
	_loaded = true
	return true

# 应用层只在没有已有武器时交付新游戏实例。
func initialize_new_weapon(weapon: WeaponInstance) -> bool:
	if not ensure_loaded() or weapon == null or not _module.owned_weapons.is_empty():
		return false
	_module.owned_weapons.append(weapon)
	_module.current_weapon_uid = weapon.unique_id
	if not _module.can_save():
		_module.clear_data()
		return false
	return true

# 返回当前拥有的武器模型，牌组由该模型持有。
func get_current_weapon() -> WeaponInstance:
	return _module.get_current_weapon()

# 保留持久牌组快照接口；远征初始化改由当前武器创建独立副本。
func get_expedition_deck() -> Dictionary:
	if not ensure_loaded() or not _module.can_save():
		return {"success": false, "cards": []}
	var weapon := get_current_weapon()
	if weapon == null:
		push_error("[PlayerSaveManager] 读取牌组快照失败：没有当前武器。")
		return {"success": false, "cards": []}
	var cards := weapon.combat_deck.get_cards()
	return {"success": true, "cards": cards, "state": "CONFIGURED_EMPTY" if cards.is_empty() else "READY"}

# 兼容持久牌组快照的身份校验，不用于远征独立副本。
func validate_deck_handoff(received: Array[CardInstance]) -> bool:
	var weapon := get_current_weapon()
	if weapon == null:
		return false
	var source := weapon.combat_deck.get_cards()
	if source.size() != received.size():
		return false
	for i in range(source.size()):
		if received[i] != source[i] or received[i].unique_id != source[i].unique_id:
			push_error("[PlayerSaveManager] 牌组交接失败：索引 %d 身份或顺序改变。" % i)
			return false
	return true

# 恢复标记只决定下次进入哪个应用场景。
func was_expedition_active() -> bool:
	return _module.expedition_was_active

# 保存失败时还原内存标记，不覆盖原文件。
func save_with_expedition_marker(active: bool) -> bool:
	if not ensure_loaded():
		return false
	var previous := _module.expedition_was_active
	_module.expedition_was_active = active
	if not SaveManager.save_game():
		_module.expedition_was_active = previous
		return false
	return true
