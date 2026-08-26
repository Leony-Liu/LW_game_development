extends Control
class_name CardLogic

#region 节点引用
@onready var cost_label: Label = %CostLable
@onready var name_label: Label = %NameLable
@export var interaction: Node 
@export var animation: Node 
#endregion

# 自身id、数据和位于手牌的位置
var card_id: int = 0
var card_slot: int
var card_data: Dictionary = {}


# 缓存自身是否处于鼠标悬停状态，由 Interaction 的信号更新
var is_locked: bool = false
var is_hovered: bool = false

# 申请处理出牌信号 (向上级发送)
signal card_played_request(card_id: int, card_slot: int)
# 申请处理弃牌信号 (向上级发送)
signal card_discarded_request(card_id: int, card_slot: int)

func _ready() -> void:
	# 将自身交给交互组件，并监听其定义的信号
	interaction.setup(self)
	interaction.hover_started.connect(_on_hover_started)
	interaction.hover_ended.connect(_on_hover_ended)
	interaction.left_clicked.connect(_on_left_clicked)
	interaction.right_clicked.connect(_on_right_clicked)
	
	# 将卡牌根节点和视觉根节点交给动画组件
	animation.setup(self, %Visuals)
	

# 供上层(PHD)自上而下调用的注入方法，接收数据
func setup(id: int, slot: int) -> void:
	card_id = id
	card_slot = slot
	_fetch_data_from_database()

# 从数据库查找自己
func _fetch_data_from_database() -> void:
	if card_id == 0: return push_warning("卡牌未配置 card_id，跳过读取。")
	card_data = CardDataBase.get_card(card_id)
	if card_data.is_empty(): return push_error("未找到 ID：%d" % card_id)

	name_label.text = tr(str(card_data.get("name_key", "CARD_NAME_UNKNOWN")))
	var is_attack: bool = str(card_data.get("categories", "attack")) == "attack"
	cost_label.text = str(card_data.get("stamina_cost" if is_attack else "mana_cost", card_data.get("cost", 0)))
	
	# 视觉配置（如颜色）交由动画节点处理
	animation.set_cost_color(cost_label, is_attack)

#region 交互响应流程
# 左键点击
func _on_left_clicked() -> void:
	if is_locked: return
	is_locked = true
	animation.play_hover_exit()
	# 申请处理出牌信号
	card_played_request.emit(card_id, card_slot)
	
# 右键点击
func _on_right_clicked() -> void:
	if is_locked: return
	is_locked = true
	animation.play_discard()
	# 申请处理弃牌信号
	card_discarded_request.emit(card_id, card_slot)
	
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

# 模拟：如果系统内部某些机制拒绝了出牌
func reject_card() -> void:
	is_locked = false
	animation.play_error_shake()
	if is_hovered:
		animation.play_hover_enter()
#endregion

# 每帧命令 Animation 更新旋转
func _process(delta: float) -> void:
	if is_hovered and not is_locked:
		animation.update_dynamic_rotation(delta, get_local_mouse_position().x, size.x)
