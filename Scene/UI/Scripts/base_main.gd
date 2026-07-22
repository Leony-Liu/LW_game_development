extends Control
# base_main.gd

# 1. 声明要动态加载的场景资源 (需在检查器中拖入对应的 .tscn)
@export_category("UI Panels")
@export var panel_character_scene: PackedScene
@export var panel_warehouse_scene: PackedScene
@export var panel_shop_scene: PackedScene
@export var panel_upgrade_scene: PackedScene
@export var panel_craft_scene: PackedScene

# 2. 绑定顶部导航按钮
@onready var btn_character = $VBoxContainer/NavigationMargin/TopNavigationBar/Btn_Character
@onready var btn_warehouse = $VBoxContainer/NavigationMargin/TopNavigationBar/Btn_Warehouse
@onready var btn_shop = $VBoxContainer/NavigationMargin/TopNavigationBar/Btn_Shop
@onready var btn_upgrade = $VBoxContainer/NavigationMargin/TopNavigationBar/Btn_Upgrade
@onready var btn_craft = $VBoxContainer/NavigationMargin/TopNavigationBar/Btn_Craft

# 3. 绑定内容展示区
@onready var content_area = $ContentArea

# 记录当前正在显示的面板节点
var current_panel_node: Control = null

func _ready() -> void:
	# 保险措施：清空 ContentArea 中可能存在的占位节点
	for child in content_area.get_children():
		child.queue_free()

	# 绑定按钮信号，通过 bind() 将对应的场景传递给切换函数
	btn_character.pressed.connect(_switch_to_panel.bind(panel_character_scene))
	btn_warehouse.pressed.connect(_switch_to_panel.bind(panel_warehouse_scene))
	btn_shop.pressed.connect(_switch_to_panel.bind(panel_shop_scene))
	btn_upgrade.pressed.connect(_switch_to_panel.bind(panel_upgrade_scene))
	btn_craft.pressed.connect(_switch_to_panel.bind(panel_craft_scene))

	# 游戏刚进入基地时，默认打开“角色”面板
	# 使用 call_deferred 确保所有自动加载单例都在第一帧初始化完毕
	call_deferred("_switch_to_panel", panel_character_scene)

# 核心切换逻辑：销毁旧的，实例化新的，并触发自动保存
func _switch_to_panel(target_scene: PackedScene) -> void:
	if target_scene == null:
		push_error("BaseMain: 目标面板的 PackedScene 未挂载，请检查右侧检查器！")
		return

	# 1. 如果当前已经有面板在显示
	if current_panel_node != null:
		# 【核心】：玩家离开上一个面板时，触发无感自动保存
		SaveManager.save_current_state()
		
		# 销毁旧面板，释放内存
		current_panel_node.queue_free()
		current_panel_node = null

	# 2. 实例化新面板并挂载到界面上
	var new_panel = target_scene.instantiate()
	content_area.add_child(new_panel)
	
	# 3. 将新面板记录为当前面板
	current_panel_node = new_panel

	# 切换音效 (取消注释即可启用)
	# BattleBus.play_sfx.emit("ui_system", "tab_switch", Vector3.ZERO)
