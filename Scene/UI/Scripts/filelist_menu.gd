extends Control

# 相关场景绑定
@export_category("Navigation")
@export var shelter_scene: PackedScene
@export var save_slot_card_scene: PackedScene
@export var main_menu : PackedScene

# 转场动画参数
@export_category("Transition")
@export_range(0.0, 2.0, 0.05) var transition_duration: float = 0.3

# 节点绑定
@onready var save_list_container: VBoxContainer = %SaveListContainer
@onready var empty_state: Label = %EmptyState
@onready var back_button: Button = %BackButton
@onready var new_save_button: Button = %NewSaveButton
@onready var name_input_modal: Control = %NameInputModal
@onready var save_name_input: LineEdit = %SaveNameInput
@onready var name_input_error: Label = %NameInputError
@onready var create_cancel_button: Button = %CreateCancelButton
@onready var create_confirm_button: Button = %CreateConfirmButton
@onready var delete_confirm_modal: Control = %DeleteConfirmModal
@onready var delete_target_label: Label = %DeleteTargetLabel
@onready var delete_cancel_button: Button = %DeleteCancelButton
@onready var delete_confirm_button: Button = %DeleteConfirmButton

var pending_delete_id: String = ""
var pending_delete_name: String = ""

# 初始化节点状态并连接所有UI组件的信号
func _ready() -> void:
	# 隐藏弹窗节点
	name_input_modal.hide()
	delete_confirm_modal.hide()

	# 绑定返回与新建存档按钮的点击事件
	back_button.pressed.connect(_return_to_main_menu)
	new_save_button.pressed.connect(_open_create_dialog)

	# 绑定创建存档弹窗的按钮及输入事件
	create_cancel_button.pressed.connect(_close_create_dialog)
	create_confirm_button.pressed.connect(_confirm_create_save)
	save_name_input.text_submitted.connect(_on_name_submitted)

	# 绑定删除存档弹窗的确认与取消事件
	delete_cancel_button.pressed.connect(_close_delete_dialog)
	delete_confirm_button.pressed.connect(_confirm_delete_save)

	# 初始刷新并加载存档列表
	_refresh_save_list()

# 执行场景切换操作，返回主菜单
func _return_to_main_menu() -> void:
	# 调用场景管理器执行带过渡动画的场景切换
	EventBus.load_scene.emit("main_menu")

# 处理全局输入事件，主要用于监听取消操作（如Esc键）来关闭弹窗或返回
func _unhandled_input(event: InputEvent) -> void:
	# 如果不是取消动作则不作处理
	if not event.is_action_pressed("ui_cancel"):
		return

	# 如果删除确认弹窗处于显示状态，则关闭弹窗并拦截输入
	if delete_confirm_modal.visible:
		_close_delete_dialog()
		get_viewport().set_input_as_handled()
		return

	# 如果名称输入弹窗处于显示状态，则关闭弹窗并拦截输入
	if name_input_modal.visible:
		_close_create_dialog()
		get_viewport().set_input_as_handled()
		return

	# 如果没有显示任何弹窗，则执行返回主菜单操作
	_return_to_main_menu()

# 刷新并重新生成存档列表UI
func _refresh_save_list() -> void:
	# 清空当前列表中的所有存档卡片
	_clear_save_cards()

	# 获取所有存档数据
	var saves: Array = SaveManager.get_all_saves()

	# 根据存档数量控制空状态提示的显示
	empty_state.visible = saves.is_empty()

	# 获取最后一次游玩的存档ID
	var last_save_id: String = SaveManager.get_last_save_id()

	# 遍历存档数据并生成对应的卡片UI
	for save_value in saves:
		# 过滤非字典类型的异常存档数据
		if typeof(save_value) != TYPE_DICTIONARY:
			continue

		# 创建单个存档卡片并标记是否为最新存档
		var save_data: Dictionary = save_value
		_create_save_card(save_data, str(save_data.get("id", "")) == last_save_id)

# 移除并销毁存档列表容器中的所有子节点
func _clear_save_cards() -> void:
	# 遍历容器子节点进行清理
	for child in save_list_container.get_children():
		save_list_container.remove_child(child)
		child.queue_free()

# 实例化并配置单个存档卡片节点
func _create_save_card(save_data: Dictionary, is_last_save: bool) -> void:
	# 检查存档卡片场景是否已正确配置
	if save_slot_card_scene == null:
		push_error("FileList: Save Slot Card Scene 未绑定。")
		return

	# 实例化存档卡片节点
	var card_node: Node = save_slot_card_scene.instantiate()

	# 校验实例化的节点类型是否正确
	if not card_node is SaveSlotCard:
		push_error("FileList: SaveSlotCard 场景脚本错误。")
		card_node.queue_free()
		return

	# 类型转换为SaveSlotCard并添加到容器中
	var card: SaveSlotCard = card_node as SaveSlotCard
	save_list_container.add_child(card)

	# 初始化卡片数据及状态
	card.setup(save_data, is_last_save)

	# 连接卡片的游玩和删除请求信号
	card.play_requested.connect(_on_save_play_requested)
	card.delete_requested.connect(_on_save_delete_requested)

# 响应存档卡片的游玩请求，触发加载流程
func _on_save_play_requested(save_id: String) -> void:
	# 调用加载方法并进入避难所场景
	_load_save_and_enter_shelter(save_id)

# 执行读取指定存档并切换至避难所场景的逻辑
func _load_save_and_enter_shelter(save_id: String) -> void:
	# 检查避难所场景是否已正确配置
	if shelter_scene == null:
		push_error("FileList: Shelter Scene 未绑定。")
		return

	# 尝试通过管理器加载存档数据，失败则中断
	if not SaveManager.load_save(save_id):
		return

	# 获取主节点（MAIN）以便进行场景切换
	var main_root: Node = _get_main_root()

	# 校验主节点是否存在
	if main_root == null:
		push_error("FileList: 找不到 MAIN。")
		return

	# 构造切换场景的回调函数及参数
	var callback: Callable = Callable(main_root, "load_scene_in_main").bind(shelter_scene, {
		"entry_source": "save_list",
		"save_id": save_id
	})

	# 调用场景管理器执行带过渡动画的场景切换
	SceneManager.transition_to(callback, transition_duration)

# 初始化并显示创建新存档的弹窗
func _open_create_dialog() -> void:
	# 清空输入框内容及错误提示
	save_name_input.text = ""
	name_input_error.text = ""
	name_input_error.hide()

	# 显示弹窗并让输入框获取焦点
	name_input_modal.show()
	save_name_input.grab_focus()

# 隐藏创建存档弹窗
func _close_create_dialog() -> void:
	# 关闭弹窗显示
	name_input_modal.hide()

# 响应输入框的回车提交事件，执行创建操作
func _on_name_submitted(_submitted_text: String) -> void:
	# 触发确认创建存档流程
	_confirm_create_save()

# 验证输入并执行新建存档的逻辑
func _confirm_create_save() -> void:
	# 获取并清理输入框的首尾空格
	var save_name: String = save_name_input.text.strip_edges()

	# 校验存档名称是否为空，为空则提示错误并重新聚焦
	if save_name.is_empty():
		name_input_error.text = "请输入存档名称。"
		name_input_error.show()
		save_name_input.grab_focus()
		return

	# 调用管理器创建新存档并获取新ID
	var new_save_id: String = SaveManager.create_new_save(save_name)

	# 校验创建结果，失败则显示错误提示
	if new_save_id.is_empty():
		name_input_error.text = "创建存档失败。"
		name_input_error.show()
		return

	# 创建成功，隐藏弹窗并直接加载进入游戏
	name_input_modal.hide()
	_load_save_and_enter_shelter(new_save_id)

# 响应存档卡片的删除请求，准备数据并显示确认弹窗
func _on_save_delete_requested(save_id: String) -> void:
	# 获取要删除的存档名称
	var save_name: String = _find_save_name(save_id)

	# 记录待删除的存档信息到全局变量中
	pending_delete_id = save_id
	pending_delete_name = save_name

	# 更新确认弹窗的提示文案并显示弹窗
	delete_target_label.text = "确定永久删除存档“%s”吗？\n该操作无法撤销。" % save_name
	delete_confirm_modal.show()

# 清除待删除数据并隐藏删除确认弹窗
func _close_delete_dialog() -> void:
	# 清空待删除的存档信息
	pending_delete_id = ""
	pending_delete_name = ""

	# 隐藏确认弹窗
	delete_confirm_modal.hide()

# 执行删除存档确认后的实际删除操作
func _confirm_delete_save() -> void:
	# 校验待删除ID是否有效，无效则直接关闭弹窗
	if pending_delete_id.is_empty():
		_close_delete_dialog()
		return

	# 调用管理器执行删除
	SaveManager.delete_save(pending_delete_id)

	# 关闭弹窗并刷新列表UI
	_close_delete_dialog()
	_refresh_save_list()

# 根据存档ID在所有存档数据中查找对应的存档名称
func _find_save_name(save_id: String) -> String:
	# 获取所有存档列表
	var saves: Array = SaveManager.get_all_saves()

	# 遍历匹配指定的存档ID
	for save_value in saves:
		# 过滤非字典类型的异常数据
		if typeof(save_value) != TYPE_DICTIONARY:
			continue

		var data: Dictionary = save_value
		# 匹配成功则返回名称，缺失则返回默认名称
		if str(data.get("id", "")) == save_id:
			return str(data.get("name", "未命名存档"))

	# 遍历完毕未找到则返回默认未命名提示
	return "未命名存档"

# 获取用于执行场景管理的主节点对象
func _get_main_root() -> Node:
	# 尝试获取当前的场景根节点
	var current_scene: Node = get_tree().current_scene

	# 如果当前节点存在且包含特定切换方法，则直接返回该节点
	if current_scene != null and current_scene.has_method("load_scene_in_main"):
		return current_scene

	# 否则从全局树中回退查找名为MAIN的节点
	return get_tree().root.get_node_or_null("MAIN")
