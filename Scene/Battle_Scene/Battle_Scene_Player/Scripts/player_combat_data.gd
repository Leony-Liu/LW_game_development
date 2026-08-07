extends Node
class_name PlayerCombatData

#绑定同级节点
@onready var calculator:PlayerCalculator = %Calculator
@onready var inventory:PlayerInventory = %Inventory
@onready var visuals = %player_3Dvisuals

# ==========================================
# 参数部分
# ==========================================
signal hp_changed(current_hp, max_hp) 
signal stamina_changed(current_stamina, max_stamina) 
signal mana_changed(current_mana, max_mana) 
signal not_enough_stamina() 
signal not_enough_mana() 

@export var current_hp: float #血量
@export var max_hp: float 
@export var current_stamina: int #体力
@export var max_stamina: int 
@export var current_mana: int #脑力
@export var max_mana: int 
@export var current_defence: float  #防御力
@export var current_shield: float #护甲值
@export var current_stamina_recover_speed: float #体力恢复速度
@export var current_mana_recover_speed: float #脑力恢复速度

var _stamina_recovery_timer: float = 0.0 
var _mana_recovery_timer: float = 0.0 

# ==========================================
# 统一状态池 (Buff/Debuff Manager)
# ==========================================
var active_buffs: Dictionary = {}

var buff_triggers: Dictionary = {
	# 【修改点】：加入了 next_atk_flat(下次攻击加数值) 和 next_atk_mult(下次攻击加倍率)
	"on_attack": ["charge", "next_attack_crit", "next_atk_flat", "next_atk_mult"], 
	"on_hit": ["perfect_block_buff"],            
	"on_turn_end": ["vulnerable"]        
}

func consume_buffs_by_trigger(trigger_type: String) -> void:
	if not buff_triggers.has(trigger_type): return
	var is_changed = false
	for buff_id in buff_triggers[trigger_type]:
		if active_buffs.has(buff_id):
			active_buffs.erase(buff_id) 
			print("💥 触发器 [%s] 消耗了 Buff: %s" % [trigger_type, buff_id])
			is_changed = true
			
	if is_changed:
		BattleBus.player_buffs_changed.emit(active_buffs)

func apply_buff(buff_id: String, value: float, duration: float) -> void:
	if active_buffs.has(buff_id):
		active_buffs[buff_id]["duration"] = max(active_buffs[buff_id]["duration"], duration)
		active_buffs[buff_id]["value"] += value 
	else:
		active_buffs[buff_id] = {"value": value, "duration": duration}
	BattleBus.player_buffs_changed.emit(active_buffs)

func remove_buff(buff_id: String) -> void:
	if active_buffs.has(buff_id):
		active_buffs.erase(buff_id)
		BattleBus.player_buffs_changed.emit(active_buffs)
		print("🗑️ 已主动消耗/移除 Buff [%s]！" % buff_id)

func _process(delta: float) -> void:
	if active_buffs.is_empty(): return
	var expired_buffs = []
	for buff_id in active_buffs:
		active_buffs[buff_id]["duration"] -= delta
		if active_buffs[buff_id]["duration"] <= 0:
			expired_buffs.append(buff_id)
			
	if expired_buffs.size() > 0:
		for buff_id in expired_buffs:
			active_buffs.erase(buff_id)
		BattleBus.player_buffs_changed.emit(active_buffs)

func get_buff_value(buff_id: String) -> float:
	if active_buffs.has(buff_id):
		return active_buffs[buff_id]["value"]
	return 0.0

# ==========================================
# 初始化：战斗开始时同步初始数据给 UI
# ==========================================
func _ready() -> void:
	call_deferred("_sync_initial_stats")

func _sync_initial_stats() -> void:
	print("玩家战斗数据：向 UI 推送初始面板数据...")
	BattleBus.player_hp_changed.emit(current_hp, max_hp)
	BattleBus.player_stamina_changed.emit(current_stamina, max_stamina)
	BattleBus.player_staminars_changed.emit(current_stamina_recover_speed)
	BattleBus.player_mana_changed.emit(current_mana, max_mana)
	BattleBus.player_manars_changed.emit(current_mana_recover_speed)
	BattleBus.player_defence_changed.emit(current_defence)
	BattleBus.player_shield_changed.emit(current_shield)

# ==========================================
# 体力、能量恢复与消耗
# ==========================================
# 根据行动轴经过的逻辑时间恢复资源。
func recover_resources_by_time(
	amount: int
) -> void:
	if amount <= 0:
		return

	_recover_stamina_by_time(amount)
	_recover_mana_by_time(amount)


func _recover_stamina_by_time(
	amount: int
) -> void:
	if current_stamina >= max_stamina:
		_stamina_recovery_timer = 0.0
		return

	var interval := maxf(
		current_stamina_recover_speed,
		1.0
	)

	_stamina_recovery_timer += float(amount)

	var old_stamina := current_stamina

	while (
		_stamina_recovery_timer >= interval
		and current_stamina < max_stamina
	):
		current_stamina += 1
		_stamina_recovery_timer -= interval

	if current_stamina >= max_stamina:
		current_stamina = max_stamina
		_stamina_recovery_timer = 0.0

	if current_stamina != old_stamina:
		stamina_changed.emit(
			current_stamina,
			max_stamina
		)

		BattleBus.player_stamina_changed.emit(
			current_stamina,
			max_stamina
		)


func _recover_mana_by_time(
	amount: int
) -> void:
	if current_mana >= max_mana:
		_mana_recovery_timer = 0.0
		return

	var interval := maxf(
		current_mana_recover_speed,
		1.0
	)

	_mana_recovery_timer += float(amount)

	var old_mana := current_mana

	while (
		_mana_recovery_timer >= interval
		and current_mana < max_mana
	):
		current_mana += 1
		_mana_recovery_timer -= interval

	if current_mana >= max_mana:
		current_mana = max_mana
		_mana_recovery_timer = 0.0

	if current_mana != old_mana:
		mana_changed.emit(
			current_mana,
			max_mana
		)

		BattleBus.player_mana_changed.emit(
			current_mana,
			max_mana
		)

# 提供未来一段逻辑时间内的资源恢复点。

func get_resource_recovery_preview(
	visible_range: int = 100
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if visible_range <= 0:
		return result

	_append_resource_recovery_preview(
		result,
		"stamina",
		current_stamina,
		max_stamina,
		current_stamina_recover_speed,
		_stamina_recovery_timer,
		visible_range
	)

	_append_resource_recovery_preview(
		result,
		"mana",
		current_mana,
		max_mana,
		current_mana_recover_speed,
		_mana_recovery_timer,
		visible_range
	)

	return result


func _append_resource_recovery_preview(
	result: Array[Dictionary],
	resource_type: String,
	current_value: int,
	max_value: int,
	recovery_interval: float,
	recovery_timer: float,
	visible_range: int
) -> void:
	var missing_amount := maxi(
		max_value - current_value,
		0
	)

	# 资源已经满时，不显示恢复点。
	if missing_amount <= 0:
		return

	var safe_interval := maxf(
		recovery_interval,
		1.0
	)

	var safe_timer := clampf(
		recovery_timer,
		0.0,
		safe_interval
	)

	var first_remaining_time := (
		safe_interval - safe_timer
	)

	if first_remaining_time <= 0.001:
		first_remaining_time = safe_interval

	for recovery_index in range(missing_amount):
		var remaining_time := (
			first_remaining_time
			+ safe_interval * float(recovery_index)
		)

		if (
			remaining_time
			> float(visible_range) + 0.001
		):
			break

		result.append({
			"resource_type": resource_type,
			"remaining_time": remaining_time
		})

func consume_stamina(cost: int) -> bool:
	if current_stamina >= cost:
		current_stamina -= cost
		_stamina_recovery_timer = 0.0 
		stamina_changed.emit(current_stamina, max_stamina) 
		BattleBus.player_stamina_changed.emit(current_stamina,max_stamina) 
		return true
	return false

func consume_mana(cost: int) -> bool:
	if current_mana >= cost:
		current_mana -= cost
		_mana_recovery_timer = 0.0 
		mana_changed.emit(current_mana, max_mana)
		BattleBus.player_mana_changed.emit(current_mana, max_mana)
		return true
	return false

# ==========================================
# 玩家受伤与格挡判定 (保持原样)
# ==========================================
func get_hit(incoming_damage: int, hit_context: String = "combat"):
	var state_machine = $"../../StateMachine" 
	var final_damage = incoming_damage
	
	if state_machine and state_machine.current_state and state_machine.current_state.name == "Parry":
		var quality = state_machine.current_state.get_parry_quality()
		if quality == "perfect":
			final_damage = 0 
			_trigger_perfect_parry_slowmo() 
			BattleBus.play_sfx.emit("sfx_player","parry",visuals.global_position)
		elif quality == "normal":
			var stamina_cost = 1 
			if consume_stamina(stamina_cost): 
				final_damage = 0 
				BattleBus.play_sfx.emit("sfx_player","parry",visuals.global_position)
	
	if final_damage > 0:
		current_hp -= final_damage
		current_hp = clampf(current_hp, 0.0, max_hp) 
		hp_changed.emit(current_hp, max_hp) 
		BattleBus.player_hp_changed.emit(current_hp, max_hp) 
		BattleBus.play_sfx.emit("sfx_player","hurt",visuals.global_position)
		
		if current_hp <= 0:
			BattleBus.player_died.emit(hit_context)

func _trigger_perfect_parry_slowmo() -> void:
	Engine.time_scale = 0.01 
	var tween = create_tween()
	tween.set_ignore_time_scale(true) 
	tween.tween_property(Engine, "time_scale", 1.0, 2)\
		.set_trans(Tween.TRANS_QUART)\
		.set_ease(Tween.EASE_OUT)
