extends Control
class_name CardLogic

# 脚本定位：纯粹的MVC视图控制器（View）。仅负责根据注入的 RuntimeCard 实例来刷新画面表现，并将玩家交互原封不动向上传递。

#region 节点引用
@onready var cost_label: Label = %CostLable
@onready var name_label: Label = %NameLable
@export var interaction: Node 
@export var animation: Node 
#endregion

# 核心数据载体（直接由上级传递注入，不再自己查数据库）
var runtime_card: RuntimeCard
var card_slot: int

# 状态缓存
var is_locked: bool = false
var is_hovered: bool = false

# 申请处理出牌信号 (向上级发送，携带实例和槽位索引)
signal card_played_request(runtime_card: RuntimeCard, card_slot: int)
# 申请处理弃牌信号 (向上级发送)
signal card_discarded_request(runtime_card: RuntimeCard, card_slot: int)

# 初始化组件，连接交互节点与动画节点的信号。
func _ready() -> void:
	interaction.setup(self)
	interaction.hover_started.connect(_on_hover_started)
	interaction.hover_ended.connect(_on_hover_ended)
	interaction.left_clicked.connect(_on_left_clicked)
	interaction.right_clicked.connect(_on_right_clicked)
	
	animation.setup(self, %Visuals)

# 依赖注入入口：由 PlayerHandDeck 自上而下调用，接收数据并完成初次画面渲染。
func setup(in_runtime_card: RuntimeCard, slot: int) -> void:
	runtime_card = in_runtime_card
	card_slot = slot
	
	# 监听数据变化，当卡牌获得/失去Buff时自动刷新画面
	runtime_card.stats_updated.connect(_update_visuals)
	
	_update_visuals()

# 渲染画面：读取 RuntimeCard 提供的方法更新文本与颜色。
func _update_visuals() -> void:
	if not runtime_card: return
	
	var is_attack: bool = str(runtime_card.base_data.get("categories", "attack")) == "attack"
	name_label.text = tr(str(runtime_card.base_data.get("name_key", "CARD_NAME_UNKNOWN")))
	
	# UI 上显示资源消耗
	cost_label.text = str(runtime_card.get_resource_cost())
	animation.set_cost_color(cost_label, is_attack)

#region 交互响应流程
# 左键点击：播放动画，并把 RuntimeCard 抛给上级。
func _on_left_clicked() -> void:
	if is_locked: return
	is_locked = true
	animation.play_hover_exit()
	card_played_request.emit(runtime_card, card_slot)
	
# 右键点击：播放弃牌动画，并向上传递弃牌请求。
func _on_right_clicked() -> void:
	if is_locked: return
	is_locked = true
	animation.play_discard()
	card_discarded_request.emit(runtime_card, card_slot)
	
# 悬浮开始
func _on_hover_started() -> void:
	is_hovered = true
	if is_locked: return
	animation.play_hover_enter()
	
# 悬浮结束
func _on_hover_ended() -> void:
	is_hovered = false
	if is_locked: return
	animation.play_hover_exit()

# 拒绝出牌模拟（外部调用解体报错）
func reject_card() -> void:
	is_locked = false
	animation.play_error_shake()
	if is_hovered:
		animation.play_hover_enter()
#endregion

# 每帧动态更新旋转（根据鼠标位置）
func _process(delta: float) -> void:
	if is_hovered and not is_locked:
		animation.update_dynamic_rotation(delta, get_local_mouse_position().x, size.x)
