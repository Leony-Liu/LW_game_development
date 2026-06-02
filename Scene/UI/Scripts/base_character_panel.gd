extends Control

@onready var enter_map_btn = $MarginContainer/Button

# 【修改】从暴露1个场景，变成暴露2个场景
@export_category("Level Navigation")
@export var target_map_world: PackedScene 
@export var target_map_ui: PackedScene 

func _ready() -> void:
	if enter_map_btn:
		enter_map_btn.pressed.connect(_on_enter_map_pressed)

func _on_enter_map_pressed() -> void:
	if not target_map_world or not target_map_ui:
		push_error("进入地图失败：请在检查器中同时配置 World 和 UI 场景！")
		return
		
	var main_root = get_tree().root.get_node_or_null("MAIN")
	if not main_root:
		return
	
	var load_map_logic = func():
		# 【修改】调用刚才在 main.gd 新写的双核加载方法
		main_root.load_combat_scene(target_map_world, target_map_ui) 
		
	SceneManager.transition_to(load_map_logic, 0.5)
