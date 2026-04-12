
extends Node

# —————— 卡牌信号 ——————
signal card_played(card_data: Dictionary, card_node: Control) # 一张牌被打出
signal card_rejected(card_node: Control) # 卡牌不能打出

# —————— 状态信号 ——————
signal player_died(death_context: String) # 玩家死亡
signal enemy_died(death_context: String)  # 敌人死亡

# —————— 过程性信号 ——————
signal player_dealt_damage(payload: Dictionary) # 传递玩家造成的伤害
signal enemy_dealt_damage(payload: Dictionary)  # 传递敌人造成的伤害

# —————— 场景转换信号 ——————
signal enter_battle_scene()#玩家已准备好进入战斗场景
