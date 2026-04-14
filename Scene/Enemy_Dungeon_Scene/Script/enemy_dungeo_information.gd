extends Node

@export var ID: int#怪物在地图中的ID
@export var BattleID: int = 20001#怪物进入战斗的类型ID
@export var TileMapReference: TileMapLayer#记录怪物所在瓦片地图
var MyNode: BSPNode = null#记录怪物所属的房间
