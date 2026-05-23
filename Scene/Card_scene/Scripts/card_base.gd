# card_base.gd (2D 视差重构版 - 最终完美版)
extends Control

# ==========================================
# 动画参数配置
# ==========================================
@export_category("动画设置")
@export var discard_duration: float = 0.15 
@export var discard_y_offset: float = -40.0 
@export var draw_duration: float = 0.20 

# 伪3D视差强度调节
@export_category("3D 视差强度")
@export var max_rotation: float = 5.0 # 最大倾斜角度
@export var text_float_height: float = 15.0 # 文字悬浮的高度（移动幅度）
@export var bg_sink_depth: float = -5.0 # 背景下沉的深度（反向移动幅度）

# ==========================================
# 节点绑定 (请确保这里的路径和你的场景树完全一致)
# ==========================================
@onready var visual_root = $Visuals
@onready var background = $Visuals/Background
@onready var illustration = $Visuals/Background/Illustration
@onready var cost_container = $Visuals/Background/CostContainer
@onready var name_container = $Visuals/Background/NameContainer
@onready var card_cost_label = $Visuals/Background/CostContainer/CostLable # 注意这里你原来拼写是 Lable，如果改了记得同步修改

# ==========================================
# 数据与状态
# ==========================================
var card_id: int
var card_data: Dictionary

var is_locked: bool = false
var is_hovered: bool = false
var is_pos_initialized: bool = false # 【核心新增】：坐标懒加载锁

# 记录基础变换
var original_min_size: Vector2
var original_pos: Vector2
var original_rot: float
var original_scale: Vector2

var orig_visual_pos: Vector2
var orig_visual_scale: Vector2

# 视差层级的原始坐标记录
var orig_bg_pos: Vector2
var orig_illu_pos: Vector2
var orig_cost_pos: Vector2
var orig_name_pos: Vector2

func _ready() -> void:
	# 强制设置枢轴点为正中心，保证缩放和旋转从中心展开
	pivot_offset = size / 2.0 
	visual_root.pivot_offset = size / 2.0
	
	_fetch_data_from_database()
	
	# 连接总线与鼠标信号
	BattleBus.card_rejected.connect(_on_card_rejected)
	self.mouse_entered.connect(_on_mouse_entered)
	self.mouse_exited.connect(_on_mouse_exited)
	self.gui_input.connect(_on_gui_input)

func _fetch_data_from_database() -> void:
	if card_id == 0: return
	card_data = CardDataBase.get_card(card_id)
	
	var cost = card_data.get("stamina_cost", 0)
	if cost == 0: 
		cost = card_data.get("mana_cost", 0)
	card_cost_label.text = str(cost) if cost > 0 else ""

# ==========================================
# 核心交互逻辑：悬停与视差
# ==========================================
func _on_mouse_entered() -> void:
	if is_locked: return
	
	# 【终极修复】：坐标懒加载！
	# 只有在鼠标第一次摸上去时，才记录 UI 的坐标。此时底层排版已经绝对稳定。
	if not is_pos_initialized:
		original_min_size = custom_minimum_size if custom_minimum_size.x != 0 else size
		original_pos = position
		original_rot = rotation_degrees
		original_scale = scale
		
		orig_visual_pos = visual_root.position
		orig_visual_scale = visual_root.scale
		
		orig_bg_pos = background.position
		orig_cost_pos = cost_container.position
		orig_name_pos = name_container.position
		orig_illu_pos = illustration.position
		
		is_pos_initialized = true # 记录完毕，上锁

	is_hovered = true
	
	# 悬浮放大动画
	var tween = create_tween().set_parallel(true)
	tween.tween_property(visual_root, "scale", orig_visual_scale * 1.1, 0.1)
	tween.tween_property(visual_root, "position:y", orig_visual_pos.y - 20.0, 0.1) 

func _on_mouse_exited() -> void:
	if not is_pos_initialized: return # 防错：如果还没初始化过，就不要乱复位
	is_hovered = false
	
	# 统统复位到懒加载时记录的原始状态
	var tween = create_tween().set_parallel(true)
	tween.tween_property(visual_root, "scale", orig_visual_scale, 0.15)
	tween.tween_property(visual_root, "position", orig_visual_pos, 0.15)
	
	tween.tween_property(self, "rotation_degrees", original_rot, 0.15)
	
	tween.tween_property(background, "position", orig_bg_pos, 0.15)
	tween.tween_property(cost_container, "position", orig_cost_pos, 0.15)
	tween.tween_property(name_container, "position", orig_name_pos, 0.15)
	tween.tween_property(illustration, "position", orig_illu_pos, 0.15)
	
func _process(delta: float) -> void:
	if is_hovered and not is_locked and is_pos_initialized:
		# 1. 获取鼠标在卡牌内部的相对坐标 (-1 到 1)
		var local_mouse = get_local_mouse_position()
		var center = size / 2.0
		var offset = (local_mouse - center) / center
		
		# 限制越界
		offset.x = clamp(offset.x, -1.0, 1.0)
		offset.y = clamp(offset.y, -1.0, 1.0)

		# 2. 整体 2D 摇摆 (模拟透视倾斜)
		var target_rotation = offset.x * max_rotation
		rotation_degrees = lerp(rotation_degrees, target_rotation, 10.0 * delta)
		
		# 3. 视差核心：分离图层！
		# 背景下沉
		background.position = lerp(background.position, orig_bg_pos - (offset * bg_sink_depth), 12.0 * delta)
		# 插图微微浮起
		illustration.position = lerp(illustration.position, orig_illu_pos + (offset * (text_float_height * 0.4)), 14.0 * delta)
		# 文字悬浮最高
		cost_container.position = lerp(cost_container.position, orig_cost_pos + (offset * text_float_height), 15.0 * delta)
		name_container.position = lerp(name_container.position, orig_name_pos + (offset * text_float_height), 15.0 * delta)

# ==========================================
# 出牌与回调
# ==========================================
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_locked: return
		print("2D卡牌被点击，发起出牌请求...")
		is_locked = true
		BattleBus.card_played.emit(card_data, self)

func _on_card_rejected(target_node: Control) -> void:
	if target_node == self:
		is_locked = false
		play_error_shake()

# ==========================================
# 动画效果表现
# ==========================================
func play_error_shake() -> void:
	modulate = Color(1, 0.2, 0.2, 1) 
	var tween = create_tween()
	tween.tween_property(self, "position:x", position.x - 10, 0.05)
	tween.tween_property(self, "position:x", position.x + 10, 0.05)
	tween.tween_property(self, "position:x", position.x, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

func play_discard_animation() -> void:
	is_locked = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE 
	var tween = create_tween().set_parallel(true) 
	tween.tween_property(self, "modulate:a", 0.0, discard_duration)
	tween.tween_property(self, "position:y", position.y + discard_y_offset, discard_duration)
	tween.chain().tween_callback(self.queue_free)

func play_draw_animation() -> void:
	custom_minimum_size.x = 0
	modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "custom_minimum_size:x", original_min_size.x, draw_duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, draw_duration)
