extends Control

## 攻击类卡牌的体力消耗文本颜色
@export var attack_cost_color: Color = Color("ff7700")
## 技能类卡牌的法力消耗文本颜色
@export var skill_cost_color: Color = Color("00bfff")

## 绑定显示卡牌消耗数值的 Label 节点
@onready var cost_label: Label = %CostLable
## 绑定显示卡牌名称的 Label 节点
@onready var name_label: Label = %NameLable
## 绑定处理底层鼠标事件的交互组件节点
@onready var interaction: Node = $InteractionComponent
## 绑定处理所有视觉反馈的动画组件节点
@onready var animation: Node = $AnimationComponent

## 当前卡牌在数据库中对应的唯一标识符
var card_id: int = 0
## 从数据库读取并缓存的当前卡牌详细属性字典
var card_data: Dictionary = {}
## 出牌或弃牌后开启的锁，防止玩家在动画期间重复操作
var is_locked: bool = false

# 节点进入场景时绑定总线信号与交互组件信号，并触发数据拉取。
func _ready() -> void:
	BattleBus.card_rejected.connect(_on_card_rejected)
	interaction.hover_started.connect(_on_hover_started)
	interaction.hover_ended.connect(_on_hover_ended)
	interaction.left_clicked.connect(_on_left_clicked)
	interaction.right_clicked.connect(_on_right_clicked)
	_fetch_data_from_database()

# 节点移出场景树时，通知战斗总线清理对应的卡牌预览状态。
func _exit_tree() -> void:
	BattleBus.card_timeline_preview_cleared.emit(self)

# 根据配置的 card_id 从数据库获取字典，更新 UI 文本和颜色。
func _fetch_data_from_database() -> void:
	if card_id == 0: return push_warning("卡牌未配置 card_id，跳过读取。")
	card_data = CardDataBase.get_card(card_id)
	if card_data.is_empty(): return push_error("未找到 ID：%d" % card_id)

	name_label.text = tr(str(card_data.get("name_key", "CARD_NAME_UNKNOWN")))
	var is_attack: bool = str(card_data.get("categories", "attack")) == "attack"
	cost_label.add_theme_color_override("font_color", attack_cost_color if is_attack else skill_cost_color)
	cost_label.text = str(card_data.get("stamina_cost" if is_attack else "mana_cost", card_data.get("cost", 0)))

# 接收交互组件的悬停开始信号，未锁定时触发时间线预览与放大动画。
func _on_hover_started() -> void:
	if is_locked or not animation.is_transform_initialized: return
	BattleBus.card_timeline_preview_requested.emit(self, maxi(int(card_data.get("time_cost", 0)), 0))
	animation.play_hover_enter()

# 接收交互组件的悬停结束信号，清理时间线预览并触发复位动画。
func _on_hover_ended() -> void:
	if not animation.is_transform_initialized: return
	BattleBus.card_timeline_preview_cleared.emit(self)
	animation.play_hover_exit()

# 左键点击，锁定卡牌并向总线正式发送出牌请求。
func _on_left_clicked() -> void:
	if is_locked: return
	is_locked = true
	BattleBus.card_timeline_preview_cleared.emit(self)
	BattleBus.card_played.emit(card_data, self)

# 右键点击，锁定卡牌并向总线正式发送弃牌请求。
func _on_right_clicked() -> void:
	if is_locked: return
	is_locked = true
	BattleBus.card_timeline_preview_cleared.emit(self)
	BattleBus.card_discard_requested.emit(self)

# 监听到总线发出的出牌被拒信号时，解除锁定、触发震动并视情况恢复预览。
func _on_card_rejected(target_node: Control) -> void:
	if target_node != self: return
	is_locked = false
	animation.play_error_shake()
	if interaction.is_hovered:
		BattleBus.card_timeline_preview_requested.emit(self, maxi(int(card_data.get("time_cost", 0)), 0))
