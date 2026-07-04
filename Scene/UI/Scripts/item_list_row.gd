extends Button # 直接继承 Button 即可
class_name ItemListRow

signal request_context_menu(uid: String, global_pos: Vector2, context: String)

var current_uid: String = ""
var location_context: String = ""

func setup(uid: String, dynamic_data: Dictionary, static_data: Dictionary, context: String) -> void:
	current_uid = uid
	location_context = context
	# ... [这里保留你设置文字、图标的代码] ...
	
func _pressed() -> void:
	# 当玩家点击这个物品行时，向外发出请求
	# 传递自己的全局坐标 (global_position)，这样菜单才知道该飞到哪里
	var popup_pos = self.global_position + Vector2(20, 20) # 偏移一点点，防止挡住当前物品名字
	request_context_menu.emit(current_uid, popup_pos, location_context)
