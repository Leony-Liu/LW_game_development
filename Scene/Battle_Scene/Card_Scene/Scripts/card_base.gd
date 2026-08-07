extends Control

# ==========================================
# 动画参数配置
# ==========================================
@export_category("动画设置")
## 弃牌动画持续时间
@export var discard_duration: float = 0.15
## 弃牌时卡牌在 Y 轴上的移动距离
@export var discard_y_offset: float = -40.0
## 抽牌动画持续时间
@export var draw_duration: float = 0.20

@export_category("悬停设置")
## 鼠标移动到卡牌左右边缘时，卡牌的最大旋转角度
@export var max_rotation: float = 5.0
## 悬停时整张卡牌的放大倍率
@export var hover_scale: float = 1.1
## 悬停时整张卡牌向上移动的距离
@export var hover_lift: float = 20.0
## 悬停状态下使用的显示层级
@export var hover_z_index: int = 100
## 卡牌跟随鼠标旋转的速度
@export var rotation_follow_speed: float = 10.0
## 悬停进入动画持续时间
@export var hover_enter_duration: float = 0.10
## 悬停退出动画持续时间
@export var hover_exit_duration: float = 0.15

# ==========================================
# 节点绑定
# ==========================================
## Visuals 包含整张卡牌的所有视觉节点
@onready var visual_root: Control = %Visuals
@onready var cost_label: Label = %CostLable
@onready var name_label: Label = %NameLable


# ==========================================
# 卡牌 UI 颜色设置
# ==========================================
@export_category("UI 颜色设置")
@export var attack_cost_color: Color = Color("ff7700")
@export var skill_cost_color: Color = Color("00bfff")

# ==========================================
# 卡牌数据
# ==========================================
## 由 CardFactory 在实例化卡牌时写入
var card_id: int = 0
## 从卡牌数据库读取出的数据
var card_data: Dictionary = {}


# ==========================================
# 运行状态
# ==========================================
## 出牌或弃牌请求发出后锁定，防止重复操作
var is_locked: bool = false
## 鼠标当前是否悬停在卡牌上
var is_hovered: bool = false
## 是否已经记录过 Container 排版后的初始变换
var is_transform_initialized: bool = false


# ==========================================
# 初始状态记录（动画方面）
# ==========================================
var original_minimum_size: Vector2
var original_rotation: float
var original_visual_position: Vector2
var original_visual_scale: Vector2
var original_z_index: int


# ==========================================
# Tween 管理
# ==========================================
var hover_tween: Tween
var reset_rotation_tween: Tween

func _ready() -> void:
	# 保存抽牌动画需要的初始宽度。
	# 这一步必须在 play_draw_animation() 之前完成，
	# 不能等到第一次悬停时才保存。
	original_minimum_size = custom_minimum_size

	if original_minimum_size.x <= 0.0:
		original_minimum_size = size

	_fetch_data_from_database()
	_connect_signals()
	call_deferred("_initialize_transform")

func _exit_tree() -> void:
	BattleBus.card_timeline_preview_cleared.emit(
		self
	)

func _connect_signals() -> void:

	if not BattleBus.card_rejected.is_connected(_on_card_rejected):
		BattleBus.card_rejected.connect(_on_card_rejected)

	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)

	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)

func _initialize_transform() -> void:
	if not is_instance_valid(visual_root):
		push_error("卡牌初始化失败：没有找到 Visuals 节点。")
		return

	# 整张卡牌围绕自身中心旋转。
	pivot_offset = size * 0.5

	# Visuals 围绕自身中心放大。
	visual_root.pivot_offset = visual_root.size * 0.5

	original_rotation = rotation_degrees
	original_visual_position = visual_root.position
	original_visual_scale = visual_root.scale
	original_z_index = z_index

	if original_minimum_size.x <= 0.0:
		original_minimum_size = size

	is_transform_initialized = true

# ==========================================
# 数据初始化
# ==========================================

# 直接从database读取卡牌数据并打包
func _fetch_data_from_database() -> void:
	if card_id == 0:
		push_warning("卡牌没有配置 card_id，跳过数据库读取。")
		return

	card_data = CardDataBase.get_card(card_id)

	if card_data.is_empty():
		push_error("卡牌数据库中没有找到 ID：%d" % card_id)
		return

	_update_card_name()
	_update_card_cost()
	

# 加载名字到UI
func _update_card_name() -> void:
	var name_key: String = str(card_data.get("name_key", "CARD_NAME_UNKNOWN"))

	name_label.text = tr(name_key)

# 加载消耗资源到UI
func _update_card_cost() -> void:
	var category: String = str(card_data.get("categories", "attack"))

	var cost: int = 0

	match category:
		"attack":
			cost = int(card_data.get("stamina_cost", 0))
			cost_label.add_theme_color_override(
				"font_color",
				attack_cost_color
			)

		"skill":
			cost = int(card_data.get("mana_cost", 0))
			cost_label.add_theme_color_override(
				"font_color",
				skill_cost_color
			)

		_:
			cost = int(card_data.get("cost", 0))

	cost_label.text = str(cost)


# ==========================================
# 悬停逻辑
# ==========================================

func _on_mouse_entered() -> void:
	if is_locked:
		return

	if not is_transform_initialized:
		_initialize_transform()

	if not is_transform_initialized:
		return

	is_hovered = true

	var preview_time := maxi(
		int(
			card_data.get(
				"time_cost",
				0
			)
		),
		0
	)

	BattleBus.card_timeline_preview_requested.emit(
		self,
		preview_time
	)

	# 记录进入悬停前的层级。
	# 如果外部手牌管理器动态修改了卡牌层级，
	# 鼠标离开时仍然可以恢复到最新值。
	original_z_index = z_index

	# 悬停卡牌显示到其他卡牌之上。
	z_index = hover_z_index

	_kill_hover_tween()

	hover_tween = create_tween()
	hover_tween.set_parallel(true)

	# 整张卡牌作为一个整体放大。
	hover_tween.tween_property(
		visual_root,
		"scale",
		original_visual_scale * hover_scale,
		hover_enter_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 整张卡牌作为一个整体向上抬起。
	hover_tween.tween_property(
		visual_root,
		"position",
		original_visual_position + Vector2(0.0, -hover_lift),
		hover_enter_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_mouse_exited() -> void:
	if not is_transform_initialized:
		return

	is_hovered = false
	
	BattleBus.card_timeline_preview_cleared.emit(self)
	
	z_index = original_z_index

	_kill_hover_tween()
	_kill_reset_rotation_tween()

	hover_tween = create_tween()
	hover_tween.set_parallel(true)

	# 整张牌复位。
	# 不再分别移动背景、插图、名称和费用节点。
	hover_tween.tween_property(
		visual_root,
		"scale",
		original_visual_scale,
		hover_exit_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(
		visual_root,
		"position",
		original_visual_position,
		hover_exit_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reset_rotation_tween = create_tween()
	reset_rotation_tween.tween_property(
		self,
		"rotation_degrees",
		original_rotation,
		hover_exit_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if not is_hovered:
		return
	if is_locked:
		return
	if not is_transform_initialized:
		return
	var half_width := size.x * 0.5
	if half_width <= 0.0:
		return
	var local_mouse_position := get_local_mouse_position()

	# 鼠标位于卡牌左边缘时接近 -1，
	# 位于卡牌右边缘时接近 1。
	var horizontal_offset := (
		local_mouse_position.x - half_width
	) / half_width

	horizontal_offset = clamp(
		horizontal_offset,
		-1.0,
		1.0
	)

	# 只旋转整张卡牌根节点。
	# Visuals 内部的背景、插图、名称和费用不会独立移动。
	var target_rotation := (
		original_rotation
		+ horizontal_offset * max_rotation
	)

	rotation_degrees = lerp(
		rotation_degrees,
		target_rotation,
		clamp(rotation_follow_speed * delta, 0.0, 1.0)
	)

func _kill_hover_tween() -> void:
	if hover_tween != null and hover_tween.is_valid():
		hover_tween.kill()
	hover_tween = null


func _kill_reset_rotation_tween() -> void:
	if (
		reset_rotation_tween != null
		and reset_rotation_tween.is_valid()
	):
		reset_rotation_tween.kill()
	reset_rotation_tween = null


# ==========================================
# 输入与出牌
# ==========================================

# 检查交互方式是否为鼠标输入
func _on_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
		
	var mouse_event := event as InputEventMouseButton
	
	if not mouse_event.pressed:
		return
	if is_locked:
		return
	match mouse_event.button_index:
		MOUSE_BUTTON_LEFT:  # 左键触发出牌请求
			_request_play_card()
			accept_event()
		MOUSE_BUTTON_RIGHT:  # 右键触发弃牌请求
			_request_discard_card()
			accept_event()


# 出牌
func _request_play_card() -> void:
	print("2D 卡牌发起出牌请求。")

	BattleBus.card_timeline_preview_cleared.emit(
		self
	)

	is_locked = true

	BattleBus.card_played.emit(
		card_data,
		self
	)



#弃牌
func _request_discard_card() -> void:
	print("2D 卡牌发起弃牌请求。")

	BattleBus.card_timeline_preview_cleared.emit(
		self
	)

	is_locked = true

	BattleBus.card_discard_requested.emit(
		self
	)


# 出牌失败
func _on_card_rejected(
	target_node: Control
) -> void:
	if target_node != self:
		return

	is_locked = false
	play_error_shake()

	# 鼠标仍停留在卡牌上时，
	# 被拒绝后重新恢复时间推进预览。
	if is_hovered:
		var preview_time := maxi(
			int(
				card_data.get(
					"time_cost",
					0
				)
			),
			0
		)

		BattleBus.card_timeline_preview_requested.emit(
			self,
			preview_time
		)

# ==========================================
# 动画效果
# ==========================================

func play_error_shake() -> void:
	var original_position_x := position.x

	modulate = Color(1.0, 0.2, 0.2, 1.0)

	var tween := create_tween()

	tween.tween_property(
		self,
		"position:x",
		original_position_x - 10.0,
		0.05
	)

	tween.tween_property(
		self,
		"position:x",
		original_position_x + 10.0,
		0.05
	)

	tween.tween_property(
		self,
		"position:x",
		original_position_x,
		0.05
	)

	tween.tween_property(
		self,
		"modulate",
		Color.WHITE,
		0.15
	)


func play_discard_animation() -> void:
	BattleBus.card_timeline_preview_cleared.emit(
		self
	)
	
	is_locked = true
	is_hovered = false

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_kill_hover_tween()
	_kill_reset_rotation_tween()

	# 弃牌时保持在较高层级，避免消失动画被其他卡牌遮挡。
	z_index = hover_z_index

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		discard_duration
	)

	tween.tween_property(
		self,
		"position:y",
		position.y + discard_y_offset,
		discard_duration
	)

	tween.chain().tween_callback(queue_free)


func play_draw_animation() -> void:
	# 如果延迟初始化还没执行，至少保证有一个可用宽度。
	if original_minimum_size.x <= 0.0:
		original_minimum_size = custom_minimum_size

	if original_minimum_size.x <= 0.0:
		original_minimum_size = size

	var target_width := original_minimum_size.x

	# Container 会根据 custom_minimum_size 重新排版卡槽。
	custom_minimum_size.x = 0.0
	modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		self,
		"custom_minimum_size:x",
		target_width,
		draw_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"modulate:a",
		1.0,
		draw_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
