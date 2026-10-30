## 管理单次远征的 Soul 整数余额。
## 只处理余额变更，不访问玩法、界面或存档。
class_name ExpeditionWallet
extends RefCounted

signal balance_changed(current_balance: int)

var _soul_balance: int = 0
var soul_balance: int:
	get:
		return _soul_balance
	set(_value):
		push_error("[ExpeditionWallet] 余额只允许通过钱包操作修改。")


# 无效初值保留原有效余额；成功初始化只通知实际变化。
func initialize(initial_soul: int = 0) -> bool:
	if initial_soul < 0:
		return false
	_set_balance(initial_soul)
	return true


# 返回唯一权威余额。
func get_soul_balance() -> int:
	return _soul_balance


# 增加正整数，并在写入前防止 int64 溢出。
func add_soul(amount: int) -> bool:
	if amount <= 0 or amount > 9223372036854775807 - _soul_balance:
		return false
	_set_balance(_soul_balance + amount)
	return true


# 先检查余额，失败不扣款或通知。
func try_spend_soul(amount: int) -> bool:
	if amount <= 0 or amount > _soul_balance:
		return false
	_set_balance(_soul_balance - amount)
	return true


# 清空只在余额变化时通知，重复调用安全。
func clear() -> void:
	_set_balance(0)


# 统一提交变更，再通知监听者。
func _set_balance(value: int) -> void:
	if value == _soul_balance:
		return
	_soul_balance = value
	balance_changed.emit(_soul_balance)
