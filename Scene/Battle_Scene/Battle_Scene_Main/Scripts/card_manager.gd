extends Node

@export_category("节点引用")
@export var hand_deck_node: Control # 指向 PlayerHandDeck，下面应当直接包含 Slot_1 ~ Slot_5
@export var card_factory: Node # 指向 CardFactory 节点
@export var player: Node # 直接绑定战斗场景中的 Player 根节点

@export_category("牌堆设置")
@export var max_hand_size: int = 5 # 最大手牌数量限制
@export var draw_action: StringName = &"draw_card" # 输入映射中的抽牌动作名称
@export var draw_stamina_cost: int = 1 # 补满手牌消耗的体力
@export var discard_stamina_cost: int = 1 # 主动弃置一张牌消耗的体力

var draw_pile: Array = [] # 抽牌堆
var hand: Array[Control] = [] # 手牌数组
var discard_pile: Array = [] # 弃牌堆
var card_count: int = 0 # 当前生成的卡牌总数
var combat_data: Node # 玩家战斗数据节点引用

# 节点初始化，连接信号、验证依赖并抽取初始手牌
func _ready() -> void:
	_connect_signals() # 连接事件总线相关的战斗信号
	if not _resolve_dependencies(): # 检查核心依赖节点是否存在
		set_process(false) # 依赖缺失则停止进程处理
		return
	_get_player_card_deck() # 初始化玩家牌堆
	_draw_initial_hand_card() # 开局抽取初始手牌

# 负责连接战斗事件总线相关的信号
func _connect_signals() -> void:
	if not BattleBus.card_successfully_played.is_connected(_on_card_successfully_played): # 检查并连接成功出牌信号
		BattleBus.card_successfully_played.connect(_on_card_successfully_played)
	if not BattleBus.card_discard_requested.is_connected(_on_card_discard_requested): # 检查并连接请求弃牌信号
		BattleBus.card_discard_requested.connect(_on_card_discard_requested)

# 检查绑定的各项节点是否连接成功，返回布尔值验证结果
func _resolve_dependencies() -> bool:
	var valid := true # 初始验证状态设为通过
	if hand_deck_node == null: # 验证手牌区域节点
		push_error("CardManager：没有绑定 hand_deck_node。")
		valid = false
	if card_factory == null: # 验证卡牌工厂节点
		push_error("CardManager：没有绑定 card_factory。")
		valid = false
	if player == null: # 备用方案：尝试从分组中获取 Player 节点
		player = get_tree().get_first_node_in_group("Player")
	if player == null: # 验证玩家节点是否存在
		push_error("CardManager：没有绑定 Player，并且场景树中也没有属于 Player 分组的节点。")
		valid = false
	else:
		combat_data = player.get_node_or_null("Data/CombatData") # 获取玩家战斗数据节点
		if combat_data == null: # 验证战斗数据节点是否存在
			push_error("CardManager：Player 下没有找到 Data/CombatData。")
			valid = false
	if not InputMap.has_action(draw_action): # 验证输入映射是否配置抽牌动作
		push_error("CardManager：输入映射中不存在动作：%s" % draw_action)
		valid = false
	return valid # 返回最终的验证结果

# 每帧检测玩家输入以触发操作
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(draw_action): # 检测是否刚刚按下抽牌键
		_request_refill_hand() # 请求补满手牌

# 检查抽牌条件，扣除体力并执行补牌逻辑
func _request_refill_hand() -> void:
	_cleanup_hand_references() # 抽牌前清理失效的手牌引用
	var needed_cards := max_hand_size - hand.size() # 计算补满手牌所需的数量
	if needed_cards <= 0: # 检查手牌是否已满
		print("card_manager：手牌已满，不需要抽牌。")
		return
	if combat_data == null: # 检查战斗数据引用是否有效
		push_error("card_manager：CombatData 无效，无法消耗体力抽牌。")
		return
	if not combat_data.has_method("consume_stamina"): # 检查是否存在体力消耗方法
		push_error("card_manager：CombatData 缺少 consume_stamina()。")
		return
	if not combat_data.consume_stamina(draw_stamina_cost): # 尝试扣除抽牌所需体力
		print("card_manager：体力不足，无法抽牌。")
		if combat_data.has_signal("not_enough_stamina"): # 如果体力不足则触发对应信号
			combat_data.not_enough_stamina.emit()
		return
	print("card_manager：消耗 %d 点体力，准备抽取 %d 张牌。" % [draw_stamina_cost, needed_cards]) # 记录抽牌日志
	draw_cards(needed_cards) # 实际执行抽牌动作

# 从 PlayerDeckManager 获取玩家牌组并初始化为抽牌堆
func _get_player_card_deck() -> void:
	var player_deck: Array = PlayerDeckManager.get_deck().duplicate() # 复制基础牌组数据以防修改原数据
	draw_pile = player_deck # 赋值给当前抽牌堆
	draw_pile.shuffle() # 将抽牌堆顺序打乱
	print("card_manager：抽牌堆初始化完成，当前张数：%d" % draw_pile.size()) # 打印初始化结果

# 游戏开始时抽取初始手牌
func _draw_initial_hand_card() -> void:
	print("card_manager：开始抽取初始手牌。") # 记录初始抽牌日志
	draw_cards(max_hand_size) # 按照最大手牌数上限进行抽牌

# 根据指定数量从牌堆抽取卡牌并生成节点
func draw_cards(amount: int) -> void:
	if amount <= 0: # 校验抽牌数量是否合法
		return
	for _index in range(amount): # 循环执行单次抽牌
		if draw_pile.is_empty(): # 如果抽牌堆为空则尝试洗牌
			_shuffle_discard_to_draw()
		if draw_pile.is_empty(): # 如果洗牌后抽牌堆仍为空则停止抽牌
			print("card_manager：抽牌堆和弃牌堆都为空。")
			break
		var empty_slot := _find_empty_slot() # 寻找手牌区域的空闲卡槽
		if empty_slot == null: # 如果没有空槽则停止抽牌
			print("card_manager：没有空闲卡槽，停止抽牌。")
			break
		var next_card_id = draw_pile.pop_front() # 从抽牌堆顶部取出一张牌的ID
		var created_node = card_factory.create_card(next_card_id) # 通过卡牌工厂生成卡牌节点
		var new_card := created_node as Control # 将生成的节点转换为 Control 类型
		if new_card == null: # 校验生成的节点类型是否正确
			push_error("card_manager：CardFactory 创建的节点不是 Control。")
			continue
		card_count += 1 # 增加生成的卡牌总数计数
		empty_slot.add_child(new_card) # 将卡牌添加到对应的空闲槽位下
		new_card.position = Vector2.ZERO # 重置新卡牌的局部坐标
		hand.append(new_card) # 将卡牌加入手牌数组记录
		if new_card.has_method("play_draw_animation"): # 检查并播放抽牌动画
			new_card.play_draw_animation()
	print("card_manager：抽牌结束，当前手牌数量：%d" % hand.size()) # 打印抽牌结束后的状态

# 遍历手牌区域，寻找第一个没有卡牌子节点的空闲槽位
func _find_empty_slot() -> Control:
	if hand_deck_node == null: # 校验手牌区域节点是否有效
		return null
	for child in hand_deck_node.get_children(): # 遍历所有槽位节点
		var slot := child as Control # 转换为 Control 类型
		if slot == null: # 跳过类型不符的节点
			continue
		if slot.get_child_count() == 0: # 发现没有子节点的槽位即判定为空槽
			return slot
	return null # 遍历结束未找到空槽返回null

# 将弃牌堆清空，打乱后重新放入抽牌堆
func _shuffle_discard_to_draw() -> void:
	if discard_pile.is_empty(): # 检查弃牌堆是否为空
		return
	draw_pile = discard_pile.duplicate() # 复制弃牌堆数组到抽牌堆
	draw_pile.shuffle() # 打乱新的抽牌堆顺序
	discard_pile.clear() # 清空旧的弃牌堆
	print("card_manager：弃牌堆已洗回抽牌堆，当前张数：%d" % draw_pile.size()) # 打印洗牌结果

# 处理卡牌成功打出后的逻辑，移出手牌并加入弃牌堆
func _on_card_successfully_played(card_node: Control) -> void:
	if card_node == null or not is_instance_valid(card_node): # 校验卡牌节点有效性
		return
	_remove_card_from_hand(card_node) # 将卡牌从手牌数组中移除
	_add_card_to_discard_pile(card_node) # 将该卡牌数据记录到弃牌堆
	if card_node.has_method("play_discard_animation"): # 检查并播放弃牌动画
		card_node.play_discard_animation()
	else:
		card_node.queue_free() # 若无动画则直接销毁卡牌节点

# 处理主动弃牌请求，校验体力消耗并执行弃牌
func _on_card_discard_requested(card_node: Control) -> void:
	if card_node == null or not is_instance_valid(card_node): # 校验卡牌节点有效性
		return
	if player == null or combat_data == null: # 检查玩家和战斗数据是否有效
		_reject_card(card_node, "玩家或 CombatData 无效，主动弃牌被拒绝。") # 无效则拒绝弃牌
		return
	if not combat_data.has_method("consume_stamina"): # 检查体力消耗方法是否存在
		_reject_card(card_node, "CombatData 缺少 consume_stamina()。") # 缺失方法则拒绝弃牌
		return
	if not combat_data.consume_stamina(discard_stamina_cost): # 尝试扣除主动弃牌所需的体力
		_reject_card(card_node, "体力不足，无法主动弃牌。") # 体力不足则拒绝弃牌
		if combat_data.has_signal("not_enough_stamina"): # 触发体力不足相关的UI信号
			combat_data.not_enough_stamina.emit()
		return
	print("card_manager：消耗 %d 点体力，主动弃牌成功。" % discard_stamina_cost) # 记录成功扣除体力
	_on_card_successfully_played(card_node) # 复用成功出牌的回收和弃牌逻辑

# 拒绝卡牌操作，发出拒绝信号以解除卡牌的锁定状态
func _reject_card(card_node: Control, reason: String) -> void:
	print("card_manager：%s" % reason) # 打印卡牌被拒绝的具体原因
	BattleBus.card_rejected.emit(card_node) # 通知事件总线卡牌操作被拒绝

# 将指定卡牌节点从手牌数组记录中安全移除
func _remove_card_from_hand(card_node: Control) -> void:
	if hand.has(card_node): # 确认手牌数组包含该节点
		hand.erase(card_node) # 从手牌数组中擦除

# 读取卡牌节点的 ID 并将其加入弃牌堆数组
func _add_card_to_discard_pile(card_node: Control) -> void:
	if "card_id" not in card_node: # 检查卡牌节点是否携带数据 ID 属性
		push_warning("card_manager：卡牌节点没有 card_id，无法记录到弃牌堆。")
		return
	discard_pile.append(card_node.card_id) # 将卡牌 ID 加入弃牌堆数组
	print("card_manager：卡牌 ID %d 进入弃牌堆，弃牌堆当前数量：%d" % [card_node.card_id, discard_pile.size()]) # 打印弃牌堆状态更新

# 倒序遍历手牌数组，清除已失效的节点引用
func _cleanup_hand_references() -> void:
	for index in range(hand.size() - 1, -1, -1): # 从后向前遍历以防止数组越界
		if not is_instance_valid(hand[index]): # 判断节点引用是否已被销毁
			hand.remove_at(index) # 移除无效的空引用

# 为当前手牌中符合条件的卡牌附加属性强化增益
func apply_buff_to_hand(target_category: String, stat_name: String, value: float) -> void:
	_cleanup_hand_references() # 强化前先清理一遍失效手牌
	var buffed_count := 0 # 记录本次成功强化的卡牌总数
	for card_node in hand: # 遍历所有当前手牌节点
		if "card_data" not in card_node: # 跳过没有数据字典的卡牌节点
			continue
		var data: Dictionary = card_node.card_data # 获取卡牌数据字典引用
		if target_category == "all" or data.get("categories", "") == target_category: # 判断卡牌是否符合目标强化分类
			var current_value = data.get(stat_name, 0) # 获取当前属性值
			data[stat_name] = current_value + value # 应用增益数值并保存回字典
			buffed_count += 1 # 增加强化计数
	print("card_manager：强化了 %d 张 %s 卡牌的 %s，增加 %f。" % [buffed_count, target_category, stat_name, value]) # 打印强化最终结果
