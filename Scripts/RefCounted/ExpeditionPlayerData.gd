## 持有单次远征的独立武器与 Soul 钱包。
## 不访问存档或场景，也不负责战斗与结算。
class_name ExpeditionPlayerData
extends RefCounted

const ExpeditionWallet = preload("res://Scripts/RefCounted/ExpeditionWallet.gd")

var _weapon_instance: WeaponInstance
var _wallet: ExpeditionWallet


# 完整复制成功后才发布新数据，失败时不保留旧远征副本。
func initialize_from_weapon(source: WeaponInstance, initial_soul: int = 0) -> bool:
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
	_weapon_instance = weapon
	_wallet = wallet
	return true


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
	_weapon_instance = null
	var wallet := _wallet
	_wallet = null
	if wallet != null:
		wallet.clear()
