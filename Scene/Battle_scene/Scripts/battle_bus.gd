extends Node


# —————— 卡牌信号 ——————
signal card_played(card_data: Dictionary, card_node: Control) # 一张牌被打出
signal card_successfully_played(card_node: Control) # 卡牌成功打出
signal card_rejected(card_node: Control) # 卡牌不能打出

# —————— 过程性信号 ——————
signal player_dealt_damage(payload: Dictionary) # 传递玩家造成的伤害
signal enemy_dealt_damage(payload: Dictionary)  # 传递敌人造成的伤害
signal enemy_died(death_context: String)  # 敌人死亡


# —————— UI 更新信号 ——————
# 敌人
signal enemy_hp_changed(current_hp: int, max_hp: int) # 敌人血量变化
# 玩家
signal player_hp_changed(current_hp: float, max_hp: float) # 玩家血量变化
signal player_stamina_changed(current_stamina: int, max_stamina: int) # 玩家体力变化
signal player_mana_changed(current_mana: int, max_mana: int) # 玩家能量变化
