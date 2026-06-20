#房间数据类
#作用：存储房间数据（不挂节点，不实例化场景）
class_name RoomData
extends Node

var id: int
var grid_pos: Vector2i
var room_type: String = "normal"

var left_room: int = -1
var right_room: int = -1
var up_room: int = -1
var down_room: int = -1
