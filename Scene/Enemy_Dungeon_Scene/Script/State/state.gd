#怪物状态基类
#怪物所有的状态都继承这个类，方便管理
class_name DungeonEnemyState
extends Node

var machine: DungeonEnemyStateMachine
var enemy: DungeonEnemy

func enter():
	pass

func exit(): 
	pass

func update(delta): 
	pass

func physics_update(delta): 
	pass
