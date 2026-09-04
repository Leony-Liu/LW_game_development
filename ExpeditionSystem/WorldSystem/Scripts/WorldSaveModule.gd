class_name WorldSaveModule
extends SaveModule

var current_seed: int = 0
var cleared_rooms: Array[String] = [] # JSON 不支持 Vector2i，转为字符串 "x,y" 存储

# 必须重写的接口
func get_module_key() -> String:
	return "world_exploration_state"

# 必须重写的接口：统筹保存数据
func get_save_data() -> Dictionary:
	return {
		"rng_seed": current_seed,
		"cleared_rooms": cleared_rooms
	}

# 必须重写的接口：恢复系统状态
func load_save_data(data: Variant) -> void:
	clear_data()
	if typeof(data) != TYPE_DICTIONARY: return
	
	current_seed = data.get("rng_seed", 0)
	var loaded_rooms = data.get("cleared_rooms", [])
	for r in loaded_rooms:
		cleared_rooms.append(str(r))
		
	print("WorldSaveModule: 地牢状态读取完毕，种子: ", current_seed)

# 必须重写的接口：清理内存
func clear_data() -> void:
	current_seed = 0
	cleared_rooms.clear()

# --- 业务逻辑 ---

# 供 WorldManager 索要种子
func get_or_create_seed() -> int:
	if current_seed == 0:
		current_seed = randi()
	return current_seed

# 探索状态变动时（如战斗胜利），记录并触发保存
func save_world_state(map_grid: Dictionary) -> void:
	cleared_rooms.clear()
	for pos in map_grid:
		if map_grid[pos].is_cleared:
			var pos_str = "%d,%d" % [pos.x, pos.y]
			cleared_rooms.append(pos_str)
			
	# 直接调用 Autoload 全局单例
	SaveManager.register_module(self)
	SaveManager.save_game()
	print("WorldSaveModule: 世界状态已通过全局 SaveManager 物理落盘。")
