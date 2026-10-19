## 管理 Battle 实体、属性装配与行动执行边界。
## 初始化失败会显式返回，不伪装成可用战斗状态。
class_name EntityManager
extends Node

# 视觉效果向上汇报（受击、飘字、UI刷新等）
signal visual_effect_generated(visual_type: String, data: Dictionary)
# AI 行动生成信号（敌人决策生成 CombatAction 后层层上报给 BattleManager 转交 Timeline）
signal enemy_action_generated(action: CombatAction)
# 某方实体阵亡报告
signal entity_died(entity: CombatEntity)

@export var player_entity: CombatEntity
@export var enemy_entity: CombatEntity
@export var enemy_ai: EnemyAI

var _player_resource_regen_progress: Dictionary = {}

# 校验依赖并连接实体与 EnemyAI 信号。
func _ready() -> void:
	if not validate_configuration():
		return
	player_entity.visual_requested.connect(_on_entity_visual_requested)
	player_entity.entity_died.connect(_on_entity_died)
	enemy_entity.visual_requested.connect(_on_entity_visual_requested)
	enemy_entity.entity_died.connect(_on_entity_died)
	enemy_ai.action_planned.connect(_on_enemy_action_planned)


# 校验场景保存的必需实体与属性引用。
func validate_configuration() -> bool:
	if player_entity == null or enemy_entity == null or enemy_ai == null:
		push_error("EntityManager: 缺少必需的 player_entity、enemy_entity 或 enemy_ai 引用。")
		return false
	if player_entity.attribute_set == null or enemy_entity.attribute_set == null:
		push_error("EntityManager: 实体缺少必需的 attribute_set 引用。")
		return false
	return true


#region 初始化装配

# 在不修改实体、AI 或 Timeline 的前提下校验初始化输入。
func can_initialize(player_data: EntityData, enemy_id: int) -> bool:
	if player_data == null:
		push_error("EntityManager: 缺少必需的 player_data。")
		return false
	if not validate_configuration():
		return false

	var enemy_res: EnemyData = AllEnemyData.get_enemy(enemy_id)
	if not enemy_res:
		push_error("EntityManager: 无法找到 ID 为 %d 的敌人数据配置" % enemy_id)
		return false
	for action in enemy_res.action_pool:
		if action == null:
			push_error("EntityManager: 敌人 %d 的 action_pool 包含空行动。" % enemy_id)
			return false
	return true


# 接收玩家与敌人输入，全部前置校验通过后装配实体并激活 AI。
func initialize(player_data: EntityData, enemy_id: int) -> bool:
	if not can_initialize(player_data, enemy_id):
		return false

	var enemy_res: EnemyData = AllEnemyData.get_enemy(enemy_id)
	_player_resource_regen_progress.clear()

	# 1. 玩家数据装载
	player_entity.initialize_from_data(player_data)
	player_entity.entity_id = "player"

	# 2. 将敌人静态属性装配到运行时实体。
	enemy_entity.entity_id = "enemy_%d" % enemy_id
	for attr_name in enemy_res.attributes.keys():
		var initial_val = float(enemy_res.attributes[attr_name])
		enemy_entity.attribute_set.register_attribute(attr_name, initial_val)

	# 3. 激活敌人 AI 并下发行动池，规划首轮行动
	enemy_ai.setup_ai(enemy_res.action_pool, enemy_entity.entity_id)
	enemy_ai.plan_initial_actions()
	return true

#endregion


#region 资源查询与扣除（供 BattleManager 出牌校验调用）

# 查询玩家资源是否充足（stamina / mana）
func can_player_afford(cost: int, resource_name: String = "stamina") -> bool:
	if not player_entity or not player_entity.attribute_set:
		return false
	var res_attr = player_entity.attribute_set.get_attribute(resource_name)
	if res_attr:
		return res_attr.get_value() >= cost
	return false

# 扣除玩家资源
func consume_player_resource(cost: int, resource_name: String = "stamina") -> void:
	if not player_entity or not player_entity.attribute_set:
		return
	var res_attr = player_entity.attribute_set.get_attribute(resource_name)
	if res_attr:
		res_attr.sub_base(float(cost))


# 按实际流逝的逻辑时间累计并结算玩家体力与法力回复。
func advance_player_resource_regeneration(delta_time: int) -> void:
	if delta_time <= 0 or player_entity == null or player_entity.attribute_set == null:
		return
	_advance_resource_regeneration("stamina", "max_stamina", "stamina_regen", delta_time)
	_advance_resource_regeneration("mana", "max_mana", "mana_regen", delta_time)


# 保留不足一次回复的进度，并一次结算跨过的全部间隔。
func _advance_resource_regeneration(
	resource_name: String,
	max_resource_name: String,
	regen_interval_name: String,
	delta_time: int
) -> void:
	var attributes := player_entity.attribute_set
	if attributes.get_attribute(resource_name) == null:
		return
	var regen_interval := attributes.get_value(regen_interval_name)
	if regen_interval <= 0.0:
		_player_resource_regen_progress.erase(resource_name)
		return

	var progress := float(_player_resource_regen_progress.get(resource_name, 0.0)) + float(delta_time)
	var completed_intervals := floori(progress / regen_interval)
	_player_resource_regen_progress[resource_name] = progress - float(completed_intervals) * regen_interval
	if completed_intervals <= 0:
		return

	var current_value := attributes.get_value(resource_name)
	var max_value := attributes.get_value(max_resource_name)
	var restored_amount := minf(float(completed_intervals), maxf(max_value - current_value, 0.0))
	if restored_amount > 0.0:
		attributes.get_attribute(resource_name).add_base(restored_amount)

#endregion


#region 结算与行动执行

# 返回当前场景树中的全部敌方实体，只提供只读枚举入口。
func get_enemy_entities() -> Array[CombatEntity]:
	var enemies: Array[CombatEntity] = []
	for node in find_children("*", "CombatEntity", true, false):
		var entity := node as CombatEntity
		if entity != null and not entity.is_player:
			enemies.append(entity)
	return enemies

# 执行到达时间刻度的 CombatAction，根据目标 ID 精准更新属性
func execute_action(action: CombatAction) -> void:
	var target_entity = _get_entity_by_id(action.target_id)
	if not target_entity:
		push_warning("EntityManager: 未找到目标实体 ID -> %s" % action.target_id)
		return

	# 1. 执行对实体属性的直接数值变更（如 HP 扣减、Shield 累加）
	for impact in action.attribute_impacts:
		target_entity.apply_attribute_impact(impact)

	# 2. 挂载状态 Buff（实体 AttributeBuff）
	for buff in action.entity_buffs:
		target_entity.apply_entity_buff("hp", buff)

	# 卡牌 Buff 由 BattleManager 单独派发给 CardManager，避免重复结算。

# 根据 ID 检索实体节点
func _get_entity_by_id(id: String) -> CombatEntity:
	if player_entity and (player_entity.entity_id == id or id == "player"):
		return player_entity
	if enemy_entity and (enemy_entity.entity_id == id or id == "enemy" or id.begins_with("enemy_")):
		return enemy_entity
	return null

#endregion


#region 信号中继转发

func _on_entity_visual_requested(visual_type: String, data: Dictionary) -> void:
	visual_effect_generated.emit(visual_type, data)

func _on_entity_died(entity: CombatEntity) -> void:
	entity_died.emit(entity)

func _on_enemy_action_planned(action: CombatAction) -> void:
	enemy_action_generated.emit(action)

#endregion
