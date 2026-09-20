# CODE_INDEX.md

> **文件作用（给人和 AI）：**这是项目的“代码导航索引”。遇到某个机制、类、方法、signal、场景或 Resource 时，先用本文件定位到真实文件，再去 `PROJECT_DUMP.md` 阅读实现。  
> **它不负责：**替代源码。任何函数行为、参数细节、场景引用是否仍有效，都应以当前真实文件为准。  
> **更新建议：**新增/删除/移动脚本、重命名类、增加重要入口或改变场景装配后重新生成/更新。  
> **基线：**`PROJECT_DUMP.md` 2026-09-20 19:17 +08:00；本索引为静态提取。

## 0. 最常用入口

| 要找的问题 | 优先读 |
| --- | --- |
| 项目启动 / Autoload | `project.godot` |
| 基地 ↔ 远征 | `Scripts/GameManager.gd`（当前占位） |
| 一次远征生命周期 | `ExpeditionSystem/Scripts/ExpeditionManager.gd`（当前占位） |
| 地图生成 | `WorldGenerator.gd` + `MapBlueprint.gd` |
| 当前房间 / 遭遇 | `WorldManager.gd` + `RoomData.gd` |
| 房间 / 门场景实例 | `RoomSet.gd` + `BattleRoom.gd` + `DoorSet.gd` + `Door.gd` |
| 玩家探索移动 / 镜头 | `PlayerController.gd` + `PlayerVisualManager.gd` |
| 战斗启动 / 胜负 / 子系统协调 | `BattleManager.gd` |
| 玩家出牌完整链 | `CardLogic.gd` → `PlayerHandDeck.gd` → `CardManager.gd` → `BattleManager.gd` → `Timeline.gd` |
| 行动队列 / 时间推进 | `Timeline.gd` |
| 伤害 / 护盾 / 属性 | `CombatAction.gd` → `EntityManager.gd` → `CombatEntity.gd` → `AttributeSet.gd` |
| 敌人 AI | `EnemyAI.gd` + `R_EnemyAction.gd` + Enemy `.tres` |
| 卡牌数值 | Card `.tres` + `RuntimeCard.gd` |
| 卡牌 Buff | `CardBuff.gd` + `RuntimeCard.gd` + `CardManager.gd` |
| 存档 | `SaveManager.gd` + `SaveModule.gd` |
| 战斗存档 | `BattleSaveModule.gd`（当前接口不一致） |

## 1. 关键场景索引

### `ExpeditionSystem/ExpeditionSystem.tscn`

根：`Expedition‌System`

主要节点：

```text
Expedition‌System
├─ WorldSystem [WorldManager.gd]
│  ├─ RoomSet [RoomSet.gd]
│  ├─ DoorSet [DoorSet.gd]
│  ├─ PlayerVisualRoot
│  │  └─ PlayerVisual [PlayerVisual.tscn]
│  └─ WorldGenerator [WorldGenerator.gd]
└─ UISystem
```

主要绑定：

- `WorldManager.world_generator -> WorldGenerator`
- `WorldManager.room_set -> RoomSet`
- `WorldManager.door_set -> DoorSet`
- `WorldManager.player_visual -> PlayerVisualRoot/PlayerVisual`
- `WorldManager.default_blueprint -> test_mapblueprint.tres`

**未见：** `ExpeditionManager`、`BattleSystem`。

### `ExpeditionSystem/BattleSystem/BattleSystem.tscn`

```text
BattleSystem [BattleManager.gd]
├─ CombatManager [缺失引用 CombatManager.gd]
│  ├─ Timeline [Timeline.gd]
│  ├─ EnemyAI [EnemyAI.gd]
│  └─ EntityManager [EntityManager.gd]
│     ├─ PlayerEntity [CombatEntity.gd]
│     │  └─ AttributeSet [AttributeSet.gd]
│     └─ EnemyEntity [CombatEntity.gd]
│        └─ AttributeSet [AttributeSet.gd]
└─ UI
   ├─ CardSystem [CardSystem.tscn / CardManager.gd]
   └─ PlayerInformation
```

当前根 `BattleManager` 只绑定 `card_manager`；`timeline` / `entity_manager` 未见绑定。

### `CardSystem.tscn`

- 根 `CardSystem` → `CardManager.gd`
- `player_hand_deck -> PlayerHandDeck`
- `hand_limit = 6`

### `player_hand_deck.tscn`

- 根 `PlayerHandDeck` → `PlayerHandDeck.gd`
- `card_scene -> Card.tscn`

### `Card.tscn`

- 根 `Card` → `CardLogic.gd`
- `InteractionComponent` → `Card_Interaction.gd`
- `AnimationComponent` → `Card_Animation.gd`
- 主要 UI：Cost / Name / Description

### `PlayerVisual.tscn`

- `PlayerVisual` → `PlayerVisualManager.gd`
- `Player` → `PlayerController.gd`
- `Head` → `HeadController.gd`
- `CameraBobMount` → `CameraBobMount.gd`
- `DebugFreeCamera` → `DebugFreeCamera.gd`

场景覆盖：
- `walk_speed = 2.5`
- `sprint_speed = 4.5`

## 2. 数据 / Resource 索引

### 卡牌模板

目录：`Scripts/CardData/Cards/`

- `Heavyblow.tres` → ID 1001 重劈
- `Inspringsk.tres` → ID 1002 迅跃斩
- `Lethalsk.tres` → ID 1003 致命斩击
- `Quickslash.tres` → ID 1004 快砍
- `Slash.tres` → ID 1005 劈砍
- `S_Chargeup.tres` → ID 2001 蓄力
- `S_Staggerstep.tres` → ID 2002 崩势步

定义类型：

`Scripts/Resource/Card/R_carddata.gd` → `CardData`

数据库：

`Scripts/CardData/AllCardData.gd` → Autoload `AllCardData`

### 敌人模板

目录：`Scripts/EnemyData/EnemyDatas/`

- `testenemy1.tres` → ID 1001 / level 0
- `testenemy2.tres` → ID 1002 / level 1

定义：

- `Scripts/Resource/Enemy/R_EnemyData.gd` → `EnemyData`
- `Scripts/Resource/Enemy/R_EnemyAction.gd` → `EnemyAction`

数据库：

`Scripts/EnemyData/AllEnemyData.gd` → Autoload `AllEnemyData`

### 地图配置

- `Scripts/MapBlueprint.gd` → `MapBlueprint`
- `ExpeditionSystem/WorldSystem/Scripts/test_mapblueprint.tres` → 当前 `ExpeditionSystem.tscn` 绑定的默认蓝图
- `RoomData.gd` → 每个房间的运行/配置数据

## 3. 关键调用链

### 3.1 探索

```text
WorldManager._ready()
→ WorldManager.init_map()
→ WorldGenerator.generate()
→ RoomSet.build_rooms()
→ DoorSet.build_doors()
→ WorldManager.enter_explore_mode()
```

### 3.2 开门到遭遇

```text
Door.open_door()
→ door_opened
→ DoorSet.door_opened_relay
→ WorldManager._on_door_opened()
→ enter_preparing_battle_mode(room)
→ enter_battle_mode()
```

当前到这里停止，没有真正调用 BattleManager。

### 3.3 玩家出牌

```text
Card_Interaction.left_clicked
→ CardLogic._on_left_clicked()
→ CardLogic.card_played_request
→ PlayerHandDeck.card_play_requested
→ CardManager._on_hand_deck_card_play_requested()
→ CardManager.card_play_requested
→ BattleManager._on_card_play_requested()
→ EntityManager.can_player_afford()
→ EntityManager.consume_player_resource()
→ CardManager.confirm_play_card()
→ Timeline.receive_card()
```

### 3.4 行动结算

```text
Timeline.action_triggered
→ BattleManager._on_timeline_action_triggered()
→ EntityManager.execute_action()
→ CombatEntity.apply_attribute_impact()
→ Attribute / AttributeSet
→ entity/visual/death signals
→ BattleManager
→ Timeline.notify_action_finished()
```

### 3.5 敌人行动

```text
EntityManager.initialize()
→ EnemyAI.setup_ai()
→ EnemyAI.plan_initial_actions()
→ EnemyAI.action_planned
→ EntityManager.enemy_action_generated
→ BattleManager._on_enemy_action_generated()
→ Timeline.add_action()
```

当前没有完整的“行动完成 → 下一次 EnemyAI 规划”链。

### 3.6 存档

```text
SaveManager.register_module(module)
→ save_game()
→ module.get_save_data()
→ JSON user://saves/<slot>.json

load_slot()
→ JSON
→ module.load_save_data()
```

## 4. 已知需要警惕的引用/接口

- `project.godot` 的 `run/main_scene` UID 在当前快照无法解析到现有 `.tscn`。
- `BattleSystem.tscn` 引用不存在于当前快照的 `CombatManager.gd`。
- `BattleManager.timeline` / `entity_manager` 未见场景绑定。
- `EntityManager.enemy_ai` 未见场景绑定。
- `BattleManager` 检查 `battle_save_module.save_initial_state()`，当前 `BattleSaveModule` 没有该方法。
- `BattleSaveModule` 使用当前 `EntityData` / `EnemyData` 中不存在的 `base_attributes`。
- `CardData.play()` 旧效果链与 `RuntimeCard.create_action()` 新效果链并存。

## 5. GDScript 符号索引

> 下表是自动从当前源码快照提取的导航信息。函数签名细节和实现请到源码正文确认。

| 文件 | class / extends | 作用 | 函数 | signals |
| --- | --- | --- | --- | --- |
| `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardBuff.gd` | `CardBuff` / `RefCounted` | 卡牌属性临时修正器。 | `_init()`, `tick_time()`, `tick_count()`, `apply_modifier()` | — |
| `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardManager.gd` | `CardManager` / `Node` | draw/hand/discard 权威牌堆与卡牌 Buff 分发。 | `_ready()`, `initialize()`, `execute_player_draw_action()`, `apply_buff_to_card()`, `apply_buff_to_all_hand_cards()`, `advance_hand_buffs_time()`, `draw_cards()`, `_on_hand_deck_card_play_requested()`, `confirm_play_card()`, `cancel_play_card()`, `discard_card()`, `discard_all_hand_pile()`, `draw_cards_to_limit()`, `_draw_single_card()`, `_reshuffle_discard_to_draw()` | `deck_initialized`, `card_drawn`, `card_play_requested`, `card_played`, `card_discarded`, `discard_shuffled_into_draw`, `hand_pile_cleared` |
| `ExpeditionSystem/BattleSystem/CardSystem/Scripts/PlayerHandDeck.gd` | `PlayerHandDeck` / `HBoxContainer` | 手牌 UI 实例与请求中继。 | `add_card_to_hand()`, `set_input_locked()`, `_on_card_played_request()`, `_on_card_discarded_request()`, `confirm_play()`, `confirm_discard()`, `reject_action()`, `_on_card_exit_finished()`, `_find_card()` | `card_play_requested`, `card_discard_requested` |
| `ExpeditionSystem/BattleSystem/CardSystem/Scripts/RuntimeCard.gd` | `RuntimeCard` / `RefCounted` | 战斗内卡牌实例、CardBuff、行动生成。 | `_init()`, `to_dictionary()`, `from_dictionary()`, `add_buff()`, `advance_time()`, `consume_action_event()`, `get_resource_cost()`, `get_time_cost()`, `get_action_name()`, `get_priority()`, `_calculate_property()`, `create_action()` | `stats_updated` |
| `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/Card_Animation.gd` | `(无 class_name)` / `Node` | 卡牌动画组件。 | `setup()`, `prepare_draw()`, `initialize_transform()`, `set_cost_color()`, `update_dynamic_rotation()`, `play_hover_enter()`, `play_hover_exit()`, `play_draw()`, `play_card_played()`, `play_discard()`, `play_error_feedback()`, `cancel_action_and_restore()`, `_prepare_exit_animation()`, `_kill_tween()`, `_emit_draw_finished()`, `_emit_exit_finished()` | `draw_finished`, `exit_finished` |
| `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/Card_Interaction.gd` | `(无 class_name)` / `Node` | 鼠标交互组件。 | `setup()`, `set_enabled()`, `_on_mouse_entered()`, `_on_mouse_exited()`, `_on_gui_input()` | `left_clicked`, `right_clicked`, `hover_started`, `hover_ended` |
| `ExpeditionSystem/BattleSystem/CardSystem/Scripts/card/Card_Logic.gd` | `CardLogic` / `Control` | 单张卡 UI 状态机与请求。 | `_ready()`, `setup()`, `_update_visuals()`, `_on_left_clicked()`, `_on_right_clicked()`, `_on_hover_started()`, `_on_hover_ended()`, `confirm_play()`, `confirm_discard()`, `reject_action()`, `_on_draw_finished()`, `_on_exit_animation_finished()`, `_process()`, `set_system_lock()` | `card_played_request`, `card_discarded_request`, `exit_finished` |
| `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/EnemyAI.gd` | `EnemyAI` / `Node` | 敌人行动池筛选、权重随机与冷却。 | `setup_ai()`, `plan_initial_actions()`, `plan_next_action()`, `_create_combat_action_from_enemy_action()` | `action_planned` |
| `ExpeditionSystem/BattleSystem/CombatSystem/Scripts/Timeline.gd` | `Timeline` / `Node` | 逻辑时间与 CombatAction 队列。 | `add_action()`, `receive_card()`, `advance_timeline_to()`, `notify_action_finished()`, `_sort_actions()`, `pop_next_action_before_or_equal()`, `get_last_enemy_action_time()`, `clear_enemy_actions()` | `timeline_data_updated`, `action_triggered`, `timeline_advancement_finished`, `time_advanced`, `_action_completed_step` |
| `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/Attribute.gd` | `Attribute` / `RefCounted` | 单个属性值与 AttributeBuff 计算。 | `initialize()`, `add_base()`, `sub_base()`, `mul_base()`, `div_base()`, `set_custom_formula()`, `add_buff()`, `remove_buff()`, `get_value()`, `_trigger_update()` | `value_changed` |
| `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/AttributeBuff.gd` | `AttributeBuff` / `RefCounted` | 属性加减乘除 Buff 数据。 | `_init()` | — |
| `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/AttributeSet.gd` | `AttributeSet` / `Node` | 实体属性集合与跨属性公式绑定。 | `register_attribute()`, `get_attribute()`, `get_value()`, `bind_custom_formula_to_attribute()` | `attribute_updated` |
| `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/CombatEntity.gd` | `CombatEntity` / `Node` | 单实体属性影响、护盾伤害、死亡事件。 | `_ready()`, `initialize_from_data()`, `apply_attribute_impact()`, `apply_entity_buff()`, `_on_attribute_updated()` | `visual_requested`, `entity_died` |
| `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/EntityManager.gd` | `EntityManager` / `Node` | 实体初始化、资源仲裁、行动落地、AI 中继。 | `_ready()`, `initialize()`, `can_player_afford()`, `consume_player_resource()`, `execute_action()`, `_get_entity_by_id()`, `_on_entity_visual_requested()`, `_on_entity_died()`, `_on_enemy_action_planned()` | `visual_effect_generated`, `card_buff_requested`, `enemy_action_generated`, `entity_died` |
| `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd` | `BattleManager` / `Node` | 战斗生命周期与 Card/Entity/Timeline 中介协调。 | `_ready()`, `_setup_connections()`, `start_battle()`, `_convert_deck_to_runtime()`, `_on_card_play_requested()`, `_on_timeline_action_triggered()`, `_on_timeline_time_advanced()`, `_on_timeline_advancement_finished()`, `_on_enemy_action_generated()`, `_on_entity_card_buff_requested()`, `_on_visual_effect_generated()`, `notify_visual_completed()`, `_on_entity_died()`, `_set_input_locked()`, `_wait_for_visual_complete()` | `battle_started`, `battle_ended`, `input_lock_changed`, `visual_effect_requested` |
| `ExpeditionSystem/BattleSystem/Scripts/BattleSaveModule.gd` | `BattleSaveModule` / `SaveModule` | 战斗存档适配；当前接口明显不一致。 | `get_module_key()`, `get_save_data()`, `load_save_data()`, `clear_data()`, `create_battle_snapshot()`, `resolve_battle()`, `process_and_get_runtime_deck()`, `process_and_get_player_data()`, `process_and_get_enemy_data()`, `_compile_input_to_runtime()`, `build_test_deck()`, `build_test_player_data()`, `build_test_enemy_data()` | — |
| `ExpeditionSystem/BattleSystem/Scripts/EntityData.gd` | `EntityData` / `RefCounted` | 玩家/通用战斗实体输入数据。 | `_init()`, `export_to_attribute_map()` | — |
| `ExpeditionSystem/Scripts/CombatAction.gd` | `CombatAction` / `RefCounted` | 统一战斗行动数据载体。 | `_init()`, `add_attribute_impact()`, `add_entity_buff()`, `add_card_buff()` | — |
| `ExpeditionSystem/Scripts/ExpeditionManager.gd` | `(无 class_name)` / `Node` | 远征协调器；当前占位。 | `_ready()`, `_process()` | — |
| `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/CameraBobMount.gd` | `CameraBobMount` / `Node3D` | 移动镜头 bob。 | `apply_bob()` | — |
| `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/DebugFreeCamera.gd` | `DebugFreeCamera` / `Camera3D` | 调试自由相机。 | `_unhandled_input()`, `_process()`, `set_active()` | — |
| `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/HeadController.gd` | `HeadController` / `Node3D` | 头部 Pitch。 | `_unhandled_input()`, `set_active()` | — |
| `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerController.gd` | `PlayerController` / `CharacterBody3D` | 第一人称水平移动与身体 Yaw。 | `_ready()`, `_unhandled_input()`, `_physics_process()`, `set_active()` | `movement_state_changed` |
| `ExpeditionSystem/WorldSystem/PlayerVisual/Scripts/PlayerVisualManager.gd` | `PlayerVisualManager` / `Node3D` | 探索/调试模式与相机/移动开关。 | `_ready()`, `change_mode()`, `_set_explore_active()`, `_set_debug_active()`, `_on_player_movement_changed()` | — |
| `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/BattleRoom.gd` | `BattleRoom` / `Node3D` | 单房间表现与 RoomData 同步。 | `_ready()`, `set_room_data()`, `build_room()`, `_setup_walls()`, `_setup_floor_and_ceiling()`, `_setup_enemies()`, `_mount_scene()`, `_clear_children()`, `set_player_inside()`, `set_player_nearby()`, `clear_enemies()` | `room_data_changed` |
| `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Door.gd` | `Door` / `Node3D` | 门交互、动画和自动关闭。 | `_ready()`, `_unhandled_input()`, `_process()`, `open_door()`, `close_door()`, `_on_interaction_area_body_entered()`, `_on_interaction_area_body_exited()` | `door_opened` |
| `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/DoorSet.gd` | `DoorSet` / `Node3D` | 按 mapdata 实例化门并中继开门事件。 | `build_doors()`, `clear_doors()` | `door_opened_relay` |
| `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/Resource/RoomData.gd` | `RoomData` / `Resource` | 单房间数据 Resource。 | — | — |
| `ExpeditionSystem/WorldSystem/RoomSystem/Scripts/RoomSet.gd` | `RoomSet` / `Node3D` | 按 mapdata 实例化房间。 | `build_rooms()`, `clear_rooms()` | — |
| `ExpeditionSystem/WorldSystem/Scripts/WorldGenerator.gd` | `WorldGenerator` / `Node` | 地图拓扑、门、敌人分布生成。 | `generate()`, `_connect_rooms()`, `_populate_enemies_and_types()`, `_pick_boss_positions()`, `_fetch_enemy_id_by_level()`, `_roll_room_type()` | — |
| `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd` | `WorldManager` / `Node` | 地图/房间/探索状态与遭遇前置切换。 | `_ready()`, `init_map()`, `enter_explore_mode()`, `enter_preparing_battle_mode()`, `enter_battle_mode()`, `finish_battle()`, `_on_door_opened()` | — |
| `Scripts/CardData/AllCardData.gd` | `(无 class_name)` / `Node` | Autoload；扫描 CardData Resource 并按 ID 建库。 | `_ready()`, `_load_all_cards()`, `get_cards()` | — |
| `Scripts/CardData/CardEffect/E_AddPoison.gd` | `E_AddPoison` / `CardEffect` | 辅助脚本 / 具体行为，按函数名和调用方继续追踪。 | — | — |
| `Scripts/CardData/CardEffect/E_Priority.gd` | `E_Priority` / `CardEffect` | 辅助脚本 / 具体行为，按函数名和调用方继续追踪。 | `execute()` | — |
| `Scripts/CardData/CardEffect/E_cost.gd` | `E_Cost` / `CardEffect` | 辅助脚本 / 具体行为，按函数名和调用方继续追踪。 | `execute()` | — |
| `Scripts/EnemyData/AllEnemyData.gd` | `(无 class_name)` / `Node` | Autoload；扫描 EnemyData Resource 并按 ID 建库。 | `_ready()`, `_load_all_enemies_from_directory()`, `get_enemy()`, `get_all_enemy_data()` | — |
| `Scripts/GameManager.gd` | `(无 class_name)` / `Node` | 应用级 Autoload；当前占位。 | `_ready()`, `_process()` | — |
| `Scripts/MapBlueprint.gd` | `MapBlueprint` / `Resource` | 地图生成参数 Resource。 | — | — |
| `Scripts/PlayerSaveManager.gd` | `(无 class_name)` / `Node` | 玩家长期数据入口；当前占位。 | `_ready()`, `_process()` | — |
| `Scripts/RefCounted/CardInstance.gd` | `CardInstance` / `RefCounted` | 可持久化/局外卡牌实例。 | `_init()`, `to_dictionary()`, `from_dictionary()`, `get_card_name()` | — |
| `Scripts/RefCounted/SaveModule.gd` | `SaveModule` / `RefCounted` | 存档业务模块抽象接口。 | `get_module_key()`, `get_save_data()`, `load_save_data()`, `clear_data()` | — |
| `Scripts/Resource/Card/R_carddata.gd` | `CardData` / `Resource` | CardData 静态卡牌模板定义。 | `play()` | — |
| `Scripts/Resource/Card/R_cardeffect.gd` | `CardEffect` / `Resource` | 旧 CardEffect 抽象入口。 | `execute()` | — |
| `Scripts/Resource/Enemy/R_EnemyAction.gd` | `EnemyAction` / `Resource` | EnemyAction 敌人行动配置。 | — | — |
| `Scripts/Resource/Enemy/R_EnemyData.gd` | `EnemyData` / `Resource` | EnemyData 静态敌人模板。 | — | — |
| `Scripts/SaveManager.gd` | `(无 class_name)` / `Node` | 存档槽位、模块注册、JSON 读写。 | `_ready()`, `register_module()`, `get_save_summaries()`, `delete_save()`, `create_new_save()`, `load_slot()`, `save_game()`, `unload_current_save()`, `_clear_all_modules()` | `save_started`, `save_finished`, `load_started`, `load_finished` |

## 6. 资源值应该去哪里找

| 数值类型 | 权威来源 |
| --- | --- |
| 卡牌基础 cost / damage / time / priority | `Scripts/CardData/Cards/*.tres` |
| 敌人 HP / level / action_pool | `Scripts/EnemyData/EnemyDatas/*.tres` |
| 地图房间数 / 遇敌率 / 精英率 | `test_mapblueprint.tres` |
| 地图拓扑常数（ROOM_SIZE / CORRIDOR_BIAS） | `WorldGenerator.gd` |
| 手牌上限 | `CardSystem.tscn` |
| 玩家探索 walk/sprint 实际值 | `PlayerVisual.tscn`（会覆盖脚本默认值） |
| 卡牌动画时间 | `Card_Animation.gd` / 对应场景覆盖 |
| 门动画 / 距离 | `Door.gd` / `Door.tscn` 若有覆盖 |
| 屏幕 Shader 参数 | `Arts/Shader/*.gdshader` + 实际 Material/Theme 绑定 |

## 7. 新增功能时的定位模板

AI 在开始改功能前应写出：

```text
任务：
[用户需求]

权威数据：
[相关 .tres / Resource / 状态所有者]

入口：
[方法/信号]

主要实现：
[方法]

调用方：
[...]

下游：
[...]

相关场景接线：
[...]

需要同时检查：
[.tscn / .tres / project.godot]

仍不明确：
[列出，不猜]
```
