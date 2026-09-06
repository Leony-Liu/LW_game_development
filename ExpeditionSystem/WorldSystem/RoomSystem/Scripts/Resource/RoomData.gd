class_name RoomData
extends Resource

# 房间类型
enum RoomType {
	INITIAL,
	NORMAL
}

enum Direction {
	NONE,
	NORTH, # 对应 -Z
	SOUTH, # 对应 +Z
	EAST,  # 对应 +X
	WEST   # 对应 -X
}

# 房间位置
@export var room_position: Vector2 = Vector2.ZERO
# 房间类型
@export var room_type: RoomType = RoomType.NORMAL
# 是否有敌人
@export var has_enemies: bool = false
# 玩家进入的朝向
@export var entry_direction: Direction = Direction.NONE
# 玩家是否在里面
@export var is_player_inside: bool = false
# 玩家是否在附近
@export var is_player_nearby: bool = false
# 有相邻房间的方向
@export var connected_doors: Array[Direction] = []
