## 持有单次远征的独立武器、Soul 钱包与工作台会话。
## 不访问存档或场景，也不负责战斗与结算。
class_name ExpeditionPlayerData
extends RefCounted

const ExpeditionWallet = preload("res://Scripts/RefCounted/ExpeditionWallet.gd")
const CardWorkbenchSession = preload("res://Scripts/RefCounted/CardWorkbenchSession.gd")
const CardOfferGenerator = preload("res://Scripts/RefCounted/CardOfferGenerator.gd")

var _weapon_instance: WeaponInstance
var _wallet: ExpeditionWallet
var _workbench_session: CardWorkbenchSession


# 完整复制成功后才发布新数据，失败时不保留旧远征副本。
func initialize_from_weapon(source: WeaponInstance, initial_soul: int = 0, pool_source: Callable = Callable()) -> bool:
	clear()
	if initial_soul < 0:
		push_error("[ExpeditionPlayerData] 初始化失败：Soul 初值不能为负数。")
		return false
	if source == null:
		push_error("[ExpeditionPlayerData] 初始化失败：缺少来源武器。")
		return false
	if source.combat_deck == null or source.reserve_deck == null or source.combat_deck.container_id != "combat_deck" or source.reserve_deck.container_id != "reserve_deck":
		push_error("[ExpeditionPlayerData] 初始化失败：缺少有效的战斗或备用容器。")
		return false
	var weapon := source.clone()
	if weapon == null:
		return false
	var wallet := ExpeditionWallet.new()
	if not wallet.initialize(initial_soul):
		return false
	if not pool_source.is_valid():
		push_error("[ExpeditionPlayerData] 初始化失败：缺少必需的卡池查询接口。")
		wallet.clear()
		return false
	var session := CardWorkbenchSession.new()
	if not session.initialize(weapon, wallet, CardOfferGenerator.new(pool_source)):
		wallet.clear()
		return false
	_weapon_instance = weapon
	_wallet = wallet
	_workbench_session = session
	return true


# 同一远征始终返回原会话，UI 关闭不应清理此对象。
func get_workbench_session() -> CardWorkbenchSession:
	return _workbench_session


# 返回本次远征拥有的钱包，不自动补建未初始化数据。
func get_wallet() -> ExpeditionWallet:
	return _wallet


# 提供远征拥有的武器，供远征系统检查或编辑完整双牌组。
func get_weapon_instance() -> WeaponInstance:
	return _weapon_instance


# 每次读取远征战斗容器的当前顺序副本。
func get_combat_deck() -> Array[CardInstance]:
	return _weapon_instance.combat_deck.get_cards() if _weapon_instance != null else []


# 每次读取远征备用容器的当前顺序副本。
func get_reserve_deck() -> Array[CardInstance]:
	return _weapon_instance.reserve_deck.get_cards() if _weapon_instance != null else []


# 释放本模型持有的远征武器，不触及来源武器。
func clear() -> void:
	var session := _workbench_session
	_workbench_session = null
	if session != null:
		session.clear()
	_weapon_instance = null
	var wallet := _wallet
	_wallet = null
	if wallet != null:
		wallet.clear()
