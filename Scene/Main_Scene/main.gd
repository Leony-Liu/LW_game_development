extends Node

# 过场动画时长
@export_category("Transition")
var transition_duration: float = 0.25
# 场景挂载节点
@export var  scene_holder: Node

# 是否装载初始场景
var have_initial_scene : bool = false
# 记录激活场景
var active_scene : Node = null
# 用于遮挡全屏的纯黑转场矩形
var transition_rect: ColorRect
# 记录转场状态
var is_transitioning: bool = false

# 注册场景
const SCENE_DIRECTORY = {
	# 菜单
	"main_menu" : "res://Scene/UI/main_menu.tscn",
	"filelist" : "res://Scene/UI/filelist.tscn",
	"options" : "res://Scene/UI/options.tscn",
	# 基地
	"shelter" : "res://Scene/Shelter_Scene/shelter.tscn",
	# 战斗
	"battle" : "res://Scene/Battle_Scene/Battlescene.tscn"
}

# 制作转场黑屏
func _ready() -> void:

	# 连接切换场景的信号
	EventBus.load_scene.connect(_load_single_scene)

	# 生成转场画布层，层级50不会盖住100级的CRT滤镜
	var transition_layer = CanvasLayer.new()
	transition_layer.layer = 50
	add_child(transition_layer)

	# 生成全屏纯黑方块
	transition_rect = ColorRect.new()
	transition_rect.color = Color.BLACK
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.modulate.a = 0.0 
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_rect)
	
	EventBus.load_scene.emit("main_menu")

# 加载单个场景到主场景
func _load_single_scene(scene_name: String) -> void:
	# 检查要载入的场景是否正常
	if not SCENE_DIRECTORY.has(scene_name):
		printerr("Main 严重错误: 字典中未注册场景 -> ", scene_name)
		return 
		
	# 此时函数既然能走到这里，说明字典里一定有这个场景，直接放心取值
	var target_scene_path = SCENE_DIRECTORY[scene_name]
	
	# 检查是否有正在激活的场景，若有则清空
	if is_instance_valid(active_scene):
		if active_scene.get_parent() == scene_holder:
			scene_holder.remove_child(active_scene)
		active_scene.queue_free()
		active_scene = null
		
	# 如果已经在转场，就直接打断跳过，防止动画重叠
	if is_transitioning: return
	is_transitioning = true

	# 关闭鼠标交互
	transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	# 调整转场方块的透明度来实现转场效果
	var tween_out = create_tween().set_ignore_time_scale(true)
	tween_out.tween_property(transition_rect, "modulate:a", 1.0, transition_duration)
	await tween_out.finished
	
	# 加载新的场景
	var scene_to_load = load(target_scene_path)
	active_scene = scene_to_load.instantiate()
	scene_holder.add_child(active_scene)
	
	# 黑幕慢慢变回透明
	var tween_in = create_tween().set_ignore_time_scale(true)
	tween_in.tween_property(transition_rect, "modulate:a", 0.0, transition_duration)
	await tween_in.finished

	# 打开鼠标交互
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	
