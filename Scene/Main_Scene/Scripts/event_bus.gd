
extends Node


# —————— 状态信号 ——————
signal player_died(death_context: String) # 玩家死亡


# —————— 场景转换信号 ——————
signal enter_battle_scene(hit_enemies: Dictionary, support_enemies: Dictionary)#玩家已准备好进入战斗场景

#—————交互UI呼出信号————
signal interaction_prompt_requested(show: bool, text: String, target: Node)
