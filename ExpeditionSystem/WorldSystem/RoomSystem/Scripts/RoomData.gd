class_name RoomData
extends RefCounted

var grid_pos: Vector2i
var is_start_room: bool = false
var has_enemy: bool = false
var enemy_id: int = -1
var is_cleared: bool = false

# 记录与当前房间连通的方向，例如 ["N", "E"] 代表北和东有门
var doors: Array[String] = []
