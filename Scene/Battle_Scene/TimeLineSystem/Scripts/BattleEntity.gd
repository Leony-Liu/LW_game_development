# 战斗实体
class_name BattleEntity
extends Node

var entity_name: String
var hp: int = 100
var is_player: bool = false
var is_dead: bool = false

func setup(n: String, health: int, player_flag: bool) -> void:
	entity_name = n
	hp = health
	is_player = player_flag

# 受到伤害的具体执行逻辑
func take_damage(amount: int, source_name: String, manager: Node) -> void:
	if is_dead: return
	hp -= amount
	manager.log_message.emit(">>> [%s] 受击! 扣除了 %d 点生命 (剩余HP: %d)" % [entity_name, amount, hp])
	
	if hp <= 0:
		hp = 0
		is_dead = true
		manager.log_message.emit("!!! [%s] 死亡了 !!!" % entity_name)
		manager.cancel_events_for(self) # 通知 Manager 取消该实体的后续行动
