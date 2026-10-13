# ARCHITECTURE

## 0. 文档作用与阅读方式

本文记录当前实现的系统层级、SceneTree、接口、数据流和状态归属。精确文件导航见 `Docs/CODEMAP.md`；玩法规则见 `Docs/GAME_DESIGN.md`。场景装配以 `.tscn` 与 `project.godot` 为准，方法与信号以 `.gd` 为准。

| 标签 | 含义 |
| --- | --- |
| `[LIVE]` | 已核对当前保存配置或场景接线；不单独证明运行行为 |
| `[SOURCE]` | 当前源码支持，未声称完整运行时行为已验证 |
| `[VERIFY]` | 证据不足，结论待核对 |
| `[PLACEHOLDER]` | 文件或节点存在，已实现内容有限 |
| `[LEGACY]` | 当前仓库中的旧实现路径 |
| `[TARGET]` | 其他文档使用的目标态标签；本文不用于架构结论 |

树形图表示保存的 SceneTree，明确注明“概念分组”的图除外。`Resource` 与 `RefCounted` 是数据对象。

## 1. 目录

| 章节 | 内容 |
| --- | --- |
| [2. 项目架构总览](#2-项目架构总览) | 顶层分组、SceneTree、Autoload |
| [3. 系统概览](#3-系统概览) | 系统位置与角色 |
| [4. Application 系统](#4-application-系统) | 应用入口与全局服务 |
| [5. ExpeditionSystem](#5-expeditionsystem) | 远征、世界、玩家表现、外层界面 |
| [6. BattleSystem](#6-battlesystem) | 战斗内部子系统 |
| [7. 数据结构与生命周期](#7-数据结构与生命周期) | 当前数据转换 |
| [8. 跨系统通信](#8-跨系统通信) | 已核实的方法、参数、信号 |
| [9. 状态归属摘要](#9-状态归属摘要) | 当前运行时状态持有者 |

## 2. 项目架构总览

### 顶层系统树

以下是概念分组，不是另一棵 SceneTree。`Application` 仅把入口场景 `MainMenu` 与已注册的 Autoload 服务放在一起说明；没有名为 `Application` 的节点或管理器。`PlayerVisualSystem` 也是文档分组，实际节点名见下方 SceneTree。`ExpeditionSystem` 是独立保存的场景，`BattleSystem` 是其中的常驻子场景。`[LIVE]`

```text
Application
├─ MainMenu
├─ GameManager
├─ SaveManager
└─ Static Data
   ├─ AllCardData
   └─ AllEnemyData

ExpeditionSystem
├─ ExpeditionManager
├─ PrototypePlayerDataProvider
├─ WorldSystem
│  └─ PlayerVisualSystem（PlayerVisual 场景）
├─ BattleSystem
└─ UISystem
```

### 当前 SceneTree 抽象

`project.godot` 的主场景是 `MainMenuSystem/MainMenu.tscn`。远征保存场景的根节点实际名为 `Expedition‌System`，其中含 U+200C。`[LIVE]`

```text
MainMenu（主场景，Node）

Expedition‌System（独立保存场景，Node）
├─ ExpeditionManager
├─ PrototypePlayerDataProvider
├─ WorldSystem [WorldManager]
│  ├─ RoomSet
│  ├─ DoorSet
│  ├─ PlayerVisualRoot
│  │  └─ PlayerVisual [PlayerVisualManager]
│  └─ WorldGenerator
├─ BattleSystem [BattleManager]
└─ UISystem（CanvasLayer）
```

### Autoload

| 名称 | 脚本 | 当前作用 |
| --- | --- | --- |
| `GameManager` | `Scripts/GameManager.gd` | 已注册；`_ready()`、`_process()` 为空 `[LIVE][PLACEHOLDER]` |
| `SaveManager` | `Scripts/SaveManager.gd` | 存档槽、模块注册与 JSON 读写 `[LIVE][SOURCE]` |
| `AllCardData` | `Scripts/CardData/AllCardData.gd` | `CardData` 资源索引 `[LIVE][SOURCE]` |
| `AllEnemyData` | `Scripts/EnemyData/AllEnemyData.gd` | `EnemyData` 资源索引 `[LIVE][SOURCE]` |
| `godot_mcp_runtime` | `addons/godot-mcp/` | 开发工具运行时 `[LIVE]` |

## 3. 系统概览

| 系统 | 位置 | 类型 | 主要作用 |
| --- | --- | --- | --- |
| `MainMenu` | `MainMenuSystem/MainMenu.tscn` | 主场景 | 应用入口节点 |
| `GameManager` | `Scripts/GameManager.gd` | Autoload | 空的应用级脚本 `[PLACEHOLDER]` |
| `SaveManager` | `Scripts/SaveManager.gd` | Autoload | 存档文件与模块生命周期 |
| `AllCardData` / `AllEnemyData` | `Scripts/CardData/` / `Scripts/EnemyData/` | Autoload | 静态资源索引 |
| `ExpeditionManager` | `ExpeditionSystem/Scripts/ExpeditionManager.gd` | 场景节点 | 遭遇与战斗启动交接 |
| `PrototypePlayerDataProvider` | `ExpeditionSystem/Scripts/PrototypePlayerDataProvider.gd` | 场景节点 | 从 Inspector 配置生成战斗输入 |
| `WorldSystem` | `ExpeditionSystem/WorldSystem/` | 场景子树 | 地图、房间、门与世界状态 |
| `PlayerVisual` | `ExpeditionSystem/WorldSystem/PlayerVisual/` | 子场景 | 玩家控制、相机与遇敌接近 |
| `BattleSystem` | `ExpeditionSystem/BattleSystem/` | 常驻子场景 | 单场战斗装配与协调 |
| `UISystem` | `ExpeditionSystem/ExpeditionSystem.tscn` | `CanvasLayer` | 胜利与失败结果面板及操作信号 |

## 4. Application 系统

本节的 `Application` 只是阅读分组：`MainMenu` 是主场景节点，`GameManager`、`SaveManager`、`AllCardData` 和 `AllEnemyData` 是分别注册的 Autoload。当前没有统一的 `Application` 节点承载这些服务；远征内的 World/Battle 交接由 `ExpeditionManager` 处理。`[LIVE][SOURCE]`

### `MainMenu`

`MainMenu` 提供项目配置的场景入口。当前保存场景只有根节点，因此这里不承载远征、存档或战斗状态。`[LIVE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `MainMenuSystem/MainMenu.tscn`；单个 `Node` 根节点 `[LIVE]` |
| 输入 | `project.godot` 的 `run/main_scene` 指向该场景 |

### `GameManager`

`GameManager` 是已注册的 Autoload，但当前生命周期方法为空；不能据其名称推断它已负责场景切换或远征协调。`[LIVE][SOURCE][PLACEHOLDER]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `Scripts/GameManager.gd`；`GameManager` Autoload `[LIVE]` |
| 输入 | Godot 节点生命周期 `_ready()`、`_process(delta)` |
| 输出与数据 | 两个方法均为空实现 `[SOURCE][PLACEHOLDER]` |

### `SaveManager`

`SaveManager` 集中处理存档槽与文件读写，并通过 `SaveModule` 接口收集各模块的数据。模块负责提供和恢复自身数据；`SaveManager` 持有当前槽、元数据及模块注册表，不持有 World 或 Battle 的运行时事实。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `Scripts/SaveManager.gd` Autoload；接收 `SaveModule` 实例 `[LIVE][SOURCE]` |
| 输入 | `register_module(module)`、`create_new_save(slot_id, save_name)`、`load_slot(slot_id)`、`save_game()`、`unload_current_save()`；模块提供 `get_module_key()`、`get_save_data()`、`load_save_data(data)`、`clear_data()` |
| 输出 | `save_started`、`save_finished(success)`、`load_started`、`load_finished(success)`；读写 `user://saves/<slot_id>.json` |
| 数据 | `current_slot_id`、`current_metadata`、`_modules`；文件根字典含 `metadata` 与 `modules_data` |

### `AllCardData` 与 `AllEnemyData`

这两个 Autoload 分别索引卡牌与敌人静态资源，供 provider 校验卡牌 ID、供 World 和 Battle 查询敌人 ID。它们持有资源索引；原型配置、房间敌人事实和战斗内实体状态仍由各自系统持有。`[SOURCE]`

| 系统与位置 | 输入 | 输出与数据 |
| --- | --- | --- |
| `AllCardData`：`Scripts/CardData/AllCardData.gd` | `_ready()` 扫描 `Scripts/CardData/Cards/` | `get_cards() -> Dictionary`；`card_database[id]` 保存 `CardData` `[SOURCE]` |
| `AllEnemyData`：`Scripts/EnemyData/AllEnemyData.gd` | `_ready()` 扫描 `Scripts/EnemyData/EnemyDatas/` | `get_enemy(id) -> EnemyData`、`get_all_enemy_data()`；`all_enemy_data[enemy_id]` 保存 `EnemyData` `[SOURCE]` |

## 5. ExpeditionSystem

### 组成与通信

`ExpeditionSystem/ExpeditionSystem.tscn` 中，`ExpeditionManager`、`PrototypePlayerDataProvider`、`WorldSystem`、`BattleSystem`、`UISystem` 为同级子节点。`ExpeditionManager` 保存对 provider、World、Battle、UISystem 的引用。`[LIVE]`

```text
WorldManager.encounter_requested(RoomData, enemy_id)
→ ExpeditionManager
→ PrototypePlayerDataProvider.get_player_data() / get_player_deck()
→ BattleManager.start_battle(deck, player_data, enemy_id)
→ WorldManager.resolve_encounter_request(RoomData, startup_succeeded)

WorldManager.world_state_changed(previous_state, current_state)
→ ExpeditionManager
→ BattleManager.set_presentation_ready(current_state == BATTLE)
```

### `ExpeditionManager`

`ExpeditionManager` 接收 World 的遭遇请求，向 provider 取得玩家输入，交给 `BattleManager` 启动，再将启动结果交还 World。这个场景节点只协调 World/Battle 的生命周期边界：World 保留房间和探索状态，Battle 保留战斗状态。它自身保存启动重入门闩与待确认结果标志，并通过 `UISystem` 接收结果操作。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `ExpeditionSystem/ExpeditionSystem.tscn/ExpeditionManager`；`ExpeditionSystem/Scripts/ExpeditionManager.gd`；导出 `world_manager`、`battle_manager`、`prototype_player_data_provider`、`result_ui` `[LIVE]` |
| 输入 | `WorldManager.encounter_requested(room_data, enemy_id)`、`world_state_changed(previous_state, current_state)` |
| 输出 | 调用 provider、`BattleManager.start_battle()`、`WorldManager.resolve_encounter_request()`、`BattleManager.set_presentation_ready()` |
| 数据 | `_is_starting_battle` 保存启动重入门闩，`_result_pending` 保存待确认结果标志；从 `WorldManager` 查询当前房间与 pending 状态 `[SOURCE]` |

### `PrototypePlayerDataProvider`

`PrototypePlayerDataProvider` 把 Inspector 中的原型玩家配置转成 `EntityData` 和 `CardInstance`，让启动交接可以取得明确的输入。它持有原型配置并调用 `AllCardData` 校验 ID；战斗激活和运行时牌堆由 Battle 子系统管理。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `ExpeditionSystem/ExpeditionSystem.tscn/PrototypePlayerDataProvider`；`ExpeditionSystem/Scripts/PrototypePlayerDataProvider.gd` `[LIVE]` |
| 输入 | Inspector 中的玩家属性、`prototype_card_ids` 与配置标志；通过 `AllCardData.get_cards()` 校验 ID |
| 输出 | `validate_configuration() -> bool`、`get_player_data() -> EntityData`、`get_player_deck() -> Array[CardInstance]` |
| 数据 | 导出字段保存原型配置；按请求构造玩家数据和卡牌实例 `[SOURCE]` |

### `WorldSystem`

`WorldSystem` 负责地图生成后的探索流程：`WorldManager` 保存地图、当前房间、World 模式和遭遇请求，`RoomSet` / `DoorSet` 根据地图数据装配场景。遇敌时它向 `ExpeditionManager` 报告房间与敌人，并通过 `PlayerVisualManager` 完成接近表现；它不构造牌组，也不启动 Battle。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `WorldSystem` 挂 `WorldManager.gd`；子节点为 `RoomSet`、`DoorSet`、`PlayerVisualRoot/PlayerVisual`、`WorldGenerator` `[LIVE]` |
| 输入 | `default_blueprint: MapBlueprint`、`DoorSet.door_opened_relay(door)`、`PlayerVisualManager.encounter_approach_finished(transition_id, succeeded)`、`resolve_encounter_request(room_data, should_prepare_battle)` |
| 输出 | `encounter_requested(room_data, enemy_id)`、`world_state_changed(previous_state, current_state)`；调用生成器、房间与门装配、玩家表现模式 |
| 数据 | `mapdata`（`rooms` / `doors`）、`current_room_coords`、`current_state`；`RoomData` 保存房间与敌人事实 `[SOURCE]` |

`WorldGenerator.generate(blueprint)` 返回地图字典；`RoomSet` 按 `RoomData` 建立 `BattleRoom` 实例与接近锚点索引；`DoorSet` 创建 `Door` 并中继 `door_opened`。`[SOURCE]`

### `PlayerVisualSystem`

此处是 `WorldSystem/PlayerVisualRoot/PlayerVisual` 的文档分组；真实子场景根节点名为 `PlayerVisual`。它把 World 请求的探索、准备和战斗模式落实到玩家控制与相机，并将接近运镜的完成结果回报 World。`PlayerVisualManager` 及子节点持有表现状态；World 决定当前世界阶段和对应转换身份。`[LIVE][SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `PlayerVisualManager`、`PlayerController`、`HeadController`、`CameraBobMount`、`PlayerCamera`、`DebugFreeCamera`；保存于 `ExpeditionSystem/WorldSystem/PlayerVisual/PlayerVisual.tscn` `[LIVE]` |
| 输入 | `change_mode(mode)`、`start_encounter_approach(target, transition_id)`、`cancel_encounter_approach(transition_id)`；玩家运动信号 |
| 输出 | `encounter_approach_finished(transition_id, succeeded)`；更新控制、相机和鼠标模式 |
| 数据 | `current_mode`、当前接近运镜 ID；运动与相机状态由子节点持有 `[SOURCE]` |

### `UISystem`

`UISystem` 显示远征的胜利或失败结果，并把玩家确认动作发给 `ExpeditionManager`。它持有面板显示状态与操作信号；结果由 `BattleManager` 判定，清敌与恢复探索由 `WorldManager` 执行。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `ExpeditionSystem/ExpeditionSystem.tscn/UISystem`；`ExpeditionResultUI.gd`、`VictoryPanel`、`GameOverPanel` `[LIVE]` |
| 输入、输出与数据 | 接收结果显隐请求；发出 `victory_confirmed`、`restart_requested`，不修改 World 或 Battle `[SOURCE]` |

`ExpeditionManager` 接收 `BattleManager.battle_ended`。胜利确认后调用 `WorldManager.finish_battle()`，由当前 `BattleRoom.clear_enemies()` 清除敌人，再恢复探索；失败确认后重新实例化远征场景，生成新地图与玩家输入。`[SOURCE]`

## 6. BattleSystem

`BattleSystem` 常驻于远征场景，但由 `BattleManager` 控制单场战斗的启动、激活与结束。内部子系统分别持有时间、实体、卡牌、AI 与界面状态；外部通过 `BattleManager` 提交输入并接收结果。`[LIVE][SOURCE]`

### 保存的内部结构

`BattleSystem` 根节点挂 `BattleManager.gd`。`CardSystem` 实际位于 `UI` 下；`EnemyAI` 与 `EntityManager` 是同级节点。`[LIVE]`

```text
BattleSystem [BattleManager]
├─ Timeline
├─ EnemyAI
├─ EntityManager
│  ├─ PlayerEntity [CombatEntity]
│  │  └─ AttributeSet
│  └─ EnemyEntity [CombatEntity]
│     └─ AttributeSet
└─ UI（CanvasLayer）
   ├─ CardSystem [CardManager]
   │  └─ PlayerHandDeck
   ├─ PlayerInformation
   └─ CombatHUD
```

### `BattleManager`

`BattleManager` 是单场战斗的协调入口：接收远征提供的玩家数据、牌组与敌人 ID，初始化实体和卡牌子系统，再连接时间轴行动与结算。它持有战斗激活、结果及输入/表现门闩；逻辑时间、实体属性和牌堆仍由对应子系统持有。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `ExpeditionSystem/BattleSystem/BattleSystem.tscn` 根节点；导出引用绑定 `Timeline`、`EntityManager`、`UI/CardSystem`、`UI` `[LIVE]` |
| 输入 | `start_battle(external_deck, external_player_data, enemy_id) -> bool`、`set_presentation_ready(is_ready) -> bool`、`request_draw_to_full()`、`request_advance_time()`；接收 Card、Timeline、Entity 信号 |
| 输出 | `battle_started`、`battle_ended(is_player_victory)`、`input_lock_changed(is_locked)`、`visual_effect_requested(visual_type, data)`；调用 Timeline、EntityManager、CardManager |
| 数据 | `is_battle_active`、`battle_result`、启动与输入锁状态、表现就绪状态；`UI.visible` 随激活与表现状态更新 `[SOURCE]` |

`start_battle()` 将 `CardInstance[]` 转为 `RuntimeCard[]`，预检后依次初始化 `EntityManager` 和 `CardManager`。`EntityManager.entity_died` 触发战斗关闭、`Timeline.cancel_advancement()` 与 `battle_ended`。`[SOURCE]`

### `Timeline`

`Timeline` 保存逻辑时间与行动队列，按排期触发 `CombatAction`，再等待同一行动的完成确认。Battle 通过它统一推进玩家出牌、空等及敌方行动的时间；实体结算和卡牌状态不由时间轴持有。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `BattleSystem/Timeline`；`CombatSystem/Scripts/Timeline.gd` `[LIVE]` |
| 输入 | `add_action(action)`、`receive_card(runtime_card, source_id, target_id)`、`advance_timeline_to(target_time)`、`notify_action_finished(action)`、`cancel_advancement()` |
| 输出 | `action_triggered(action)`、`time_advanced(delta_time)`、`timeline_data_updated(current_time, action_line)`、`pending_action_changed(is_pending)`、`timeline_advancement_finished`；`get_scheduled_enemy_action_snapshots(horizon)` 返回字典快照 |
| 数据 | `current_time`、`action_line`、`is_advancing`、当前待确认行动；按触发时间、优先级及玩家先序排序 `[SOURCE]` |

### `EntitySystem`

`EntitySystem` 是实体相关代码的概念分组，实际由 `EntityManager`、`CombatEntity` 与 `AttributeSet` 等节点承担。`EntityManager` 用玩家数据和敌人 ID 装配实体，转交到期行动并连接 `EnemyAI`；属性数值保存在各实体的 `Attribute` 中，资源回复进度保存在 `EntityManager`。`[LIVE][SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | 概念分组；`BattleSystem/EntityManager` 下有 `PlayerEntity` 与 `EnemyEntity`，各含 `AttributeSet`；`EntityManager` 引用同级 `EnemyAI` `[LIVE]` |
| 输入 | `initialize(player_data, enemy_id)`、`execute_action(action)`、`can_player_afford(cost, resource_name)`、`consume_player_resource(cost, resource_name)`、`advance_player_resource_regeneration(delta_time)` |
| 输出 | `enemy_action_generated(action)`、`card_buff_requested(target_id, buff)`、`visual_effect_generated(visual_type, data)`、`entity_died(entity)`；`get_enemy_entities()` |
| 数据 | `CombatEntity.attribute_set` 中的 `Attribute` 保存战斗数值；`EntityManager._player_resource_regen_progress` 保存分段回复进度 `[SOURCE]` |

`EntityManager.initialize()` 从 `EntityData` 注册玩家属性，从 `AllEnemyData.get_enemy(enemy_id)` 注册敌人属性并注入 AI 行动池。`CombatEntity.apply_attribute_impact()` 处理属性冲击，负向 `hp` 先扣 `shield`。`[SOURCE]`

### `CardSystem`

`CardSystem` 负责战斗内牌组和手牌：`CardManager` 持有抽牌、手牌、弃牌堆并处理卡牌请求，手牌节点负责界面输入。它接收 `BattleManager` 转换后的 `RuntimeCard`；出牌是否可支付以及何时进入时间轴由 `BattleManager` 协调，单卡 Buff 保存在该 `RuntimeCard`。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `BattleSystem/UI/CardSystem` 挂 `CardManager.gd`；子场景含 `PlayerHandDeck`，卡牌节点由 `Card.tscn` 实例化 `[LIVE]` |
| 输入 | `initialize(player_deck: Array[RuntimeCard])`、`draw_cards(amount)`、`confirm_play_card(runtime_card)`、`discard_card(runtime_card)`、`advance_hand_buffs_time(delta_time)`；`PlayerHandDeck.card_play_requested` |
| 输出 | `deck_initialized`、`card_drawn`、`card_play_requested`、`card_played`、`card_discarded`、`discard_shuffled_into_draw`、`hand_pile_cleared`；更新手牌节点 |
| 数据 | `draw_pile`、`hand_pile`、`discard_pile`；每张 `RuntimeCard.active_buffs` 保存战斗内卡牌 Buff `[SOURCE]` |

### `EnemyAI`

`EnemyAI` 根据 `EntityManager` 注入的行动池与敌我 ID 规划 `CombatAction`，再经 `EntityManager` 和 `BattleManager` 交给 `Timeline` 排期。它持有行动池、冷却和规划时间；敌人属性属于 `CombatEntity`，行动排期属于 `Timeline`。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `BattleSystem/EnemyAI`；`CombatSystem/Scripts/EnemyAI.gd` `[LIVE]` |
| 输入 | `setup_ai(action_pool, entity_id, target_id)`、`plan_initial_actions()`、`plan_next_action(current_timeline_time)` |
| 输出 | `action_planned(action: CombatAction)`；经 `EntityManager.enemy_action_generated` 进入 `Timeline.add_action()` |
| 数据 | `_action_pool`、`_cooldown_tracker`、`_last_planned_time`、施法者与目标 ID `[SOURCE]` |

当前 `EntityManager.initialize()` 调用 `plan_initial_actions()`，以 `EnemyAction` 生成首个排期行动。`[SOURCE]`

### 战斗 `UI`

战斗 `UI` 展示战斗状态并把手牌操作送往 `CardManager`；`CombatHUD` 从 Battle、Timeline、Entity 和 Card 信号刷新文本。`BattleManager` 决定整层界面何时可见及输入是否锁定；界面保存刷新与卡牌节点状态，不持有战斗结果或属性数值。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `BattleSystem/UI` 为 `CanvasLayer`；含 `CardSystem`、`PlayerInformation`、`CombatHUD` `[LIVE]` |
| 输入 | `BattleManager` 控制 `UI.visible`；`CombatHUD` 监听 Battle、Timeline、Entity、Card 信号；`PlayerHandDeck` 与 `CardLogic` 接收卡牌数据和输入锁 |
| 输出 | `CardLogic.card_played_request` → `PlayerHandDeck.card_play_requested` → `CardManager.card_play_requested`；`CombatHUD` 刷新玩家、敌人、牌堆、时间轴文本 |
| 数据 | `CombatHUD` 保存刷新排队与结束显示标志；`PlayerHandDeck` 保存界面输入锁和卡牌节点 `[SOURCE]` |

## 7. 数据结构与生命周期

| 数据链 | 当前转换与持有位置 | 证据 |
| --- | --- | --- |
| `MapBlueprint → WorldGenerator.generate() → mapdata → RoomSet / DoorSet` | `WorldManager.mapdata` 保存 `rooms` / `doors`；两个 Set 创建场景实例 | `[SOURCE]` |
| `RoomData → BattleRoom` | `mapdata.rooms` 的 `RoomData` 传给 `BattleRoom.room_data`；`RoomSet` 保存对象到实例的映射 | `[SOURCE]` |
| `CardData → CardInstance → RuntimeCard → CombatAction` | `AllCardData` 索引模板；provider 按 ID 构造实例；`BattleManager` 用 `card_id` 和 `card_data` 构造运行时卡；`RuntimeCard.create_action()` 生成行动 | `[SOURCE]` |
| `EntityData → CombatEntity → AttributeSet → Attribute` | provider 构造 `EntityData`；`EntityManager.initialize()` 注册玩家实体属性 | `[SOURCE]` |
| `EnemyData / EnemyAction → CombatEntity / EnemyAI → CombatAction` | `AllEnemyData.get_enemy()` 提供属性和行动池；`EntityManager` 装配敌人实体并启动首轮 AI 规划 | `[SOURCE]` |
| `RuntimeCard / EnemyAI → CombatAction → Timeline → EntityManager` | 卡牌与 AI 生成行动；Timeline 排期；BattleManager 转交到期行动 | `[SOURCE]` |
| `SaveModule → SaveManager → JSON` | 注册模块提供序列化数据；`SaveManager` 写入 `metadata` / `modules_data`，加载时回调模块 | `[SOURCE]` |

`BattleManager._convert_deck_to_runtime()` 当前使用 `CardInstance.card_id` 与 `card_data`；`CardInstance.modifiers`、`unique_id` 保存在输入实例中。`[SOURCE]`

## 8. 跨系统通信

### 远征与世界

`encounter_requested(room_data, enemy_id)` 同时传房间对象和敌人 ID，因为 World 持有房间遭遇事实，`ExpeditionManager` 需要用原对象核对 pending 请求及当前房间，并用 ID 校验和启动对应敌人。协调器决定启动结果，World 通过 `resolve_encounter_request()` 接受或释放这次请求。接近运镜的 `transition_id` 让 World 将回调匹配到当前准备转换，`succeeded` 则告知运镜结果；World 再发布状态变化供 Battle 开放表现。`[SOURCE]`

| 方向 | 接口与重要参数 | 当前传递 |
| --- | --- | --- |
| `Door → DoorSet → WorldManager` | `door_opened(door: Node3D)` → `door_opened_relay(door: Node3D)` | 门节点身份；World 根据玩家和门位置更新当前房间 `[SOURCE]` |
| `WorldManager → ExpeditionManager` | `encounter_requested(room_data: RoomData, enemy_id: int)` | 当前房间原对象及敌人 ID `[SOURCE]` |
| `ExpeditionManager → WorldManager` | `is_encounter_pending(room_data)`、`has_valid_encounter_approach(room_data, enemy_id)`、`resolve_encounter_request(room_data, should_prepare_battle)` | 校验并接受或释放同一遭遇请求 `[SOURCE]` |
| `WorldManager → PlayerVisualManager` | `change_mode(mode: String)`、`start_encounter_approach(target: Node3D, transition_id: int)` | World 模式与房间接近锚点 `[SOURCE]` |
| `PlayerVisualManager → WorldManager` | `encounter_approach_finished(transition_id: int, succeeded: bool)` | 接近完成身份与结果；World 校验后进入 `BATTLE` `[SOURCE]` |
| `WorldManager → ExpeditionManager → BattleManager` | `world_state_changed(previous_state: int, current_state: int)` → `set_presentation_ready(is_ready: bool)` | `BATTLE` 状态开放战斗 UI 与输入表现门闩 `[SOURCE]` |

### 战斗与数据

启动接口把 `external_deck`、`external_player_data` 和 `enemy_id` 一起交给 `BattleManager`：前两项来自 provider 的原型输入，敌人 ID 来自 World 的房间事实。Battle 将牌组转为 `RuntimeCard`，并让 `EntityManager` 按玩家数据和敌人资源建立实体。随后各子系统传递同一个 `CombatAction` 供排期、结算及完成确认；`time_advanced(delta_time)` 将实际流逝时间交给卡牌 Buff 和资源回复的持有者。`[SOURCE]`

| 方向 | 接口与重要参数 | 当前传递 |
| --- | --- | --- |
| `ExpeditionManager → PrototypePlayerDataProvider` | `validate_configuration()`、`get_player_data()`、`get_player_deck()` | `EntityData` 与 `Array[CardInstance]` `[SOURCE]` |
| `ExpeditionManager → BattleManager` | `start_battle(external_deck: Array[CardInstance], external_player_data: EntityData, enemy_id: int) -> bool` | 战斗启动输入和成败结果 `[SOURCE]` |
| `BattleManager → EntityManager / CardManager` | `EntityManager.can_initialize(player_data: EntityData, enemy_id: int)` / `initialize(player_data: EntityData, enemy_id: int)`；`CardManager.can_initialize(player_deck: Array[RuntimeCard])` / `initialize(player_deck: Array[RuntimeCard])` | 玩家实体输入与运行时牌组 `[SOURCE]` |
| `EnemyAI → EntityManager → BattleManager → Timeline` | `action_planned(action)` → `enemy_action_generated(action)` → `add_action(action)` | `CombatAction` `[SOURCE]` |
| `CardLogic → PlayerHandDeck → CardManager → BattleManager` | `card_played_request(runtime_card)` → `card_play_requested(runtime_card)` | 当前手牌的 `RuntimeCard` `[SOURCE]` |
| `BattleManager → Timeline` | `receive_card(runtime_card, source_id, target_id)`、`advance_timeline_to(target_time)` | 卡牌行动或空等目标时间 `[SOURCE]` |
| `Timeline → BattleManager → EntityManager` | `action_triggered(action)` → `execute_action(action)` | 到期 `CombatAction` `[SOURCE]` |
| `BattleManager → Timeline` | `notify_action_finished(action)`；战斗结束调用 `cancel_advancement()` | 使用同一行动引用确认结算 `[SOURCE]` |
| `Timeline → BattleManager → CardManager / EntityManager` | `time_advanced(delta_time)` → `advance_hand_buffs_time(delta_time)` / `advance_player_resource_regeneration(delta_time)` | 实际流逝的逻辑时间段 `[SOURCE]` |
| `CombatEntity → EntityManager → BattleManager` | `entity_died(entity)`；`visual_requested` → `visual_effect_generated` → `visual_effect_requested` | 阵亡实体与表现请求；BattleManager 发出 `battle_ended(is_player_victory)` `[SOURCE]` |
| `EntityManager / BattleManager → CardManager` | `card_buff_requested(target_id, buff)` 与 BattleManager 遍历 `action.card_buffs` 均调用 `apply_buff_to_all_hand_cards(buff)` | 同一 `card_buffs` 当前存在两条应用路径 `[SOURCE]` |

### 重要参数

| 参数 | 类型 | 用途 |
| --- | --- | --- |
| `room_data` | `RoomData` | 保持遭遇请求与当前房间的对象身份 |
| `enemy_id` | `int` | 查询 `AllEnemyData` 并初始化敌方实体 |
| `external_deck` | `Array[CardInstance]` | 转换为战斗内 `RuntimeCard` 牌组 |
| `external_player_data` | `EntityData` | 初始化玩家 `CombatEntity` 属性 |
| `transition_id` | `int` | 对应一次接近运镜与 World 模式转换 |
| `action` | `CombatAction` | 在 AI / Card、Timeline、Entity 间传递行动及完成确认 |
| `delta_time` | `int` | 推进手牌 Buff 时间和玩家资源回复 |

## 9. 状态归属摘要

沿接口读取或请求变更状态，避免把收到的参数当成新的状态归属：`ExpeditionManager` 仅保存跨系统启动与结果确认状态；`WorldManager` 持有房间、遭遇和 World 模式；`BattleManager` 持有单场战斗生命周期与结果。玩家表现、时间轴、实体属性、AI 与牌堆各由下表所列节点或对象持有。`[SOURCE]`

| 状态 | 当前持有者 | 证据 |
| --- | --- | --- |
| 战斗启动重入门闩、待确认结果标志 | `ExpeditionManager` | `[SOURCE]` |
| 地图 `mapdata`、当前房间 `current_room_coords`、遭遇请求 | `WorldManager` | `[SOURCE]` |
| World 模式 `current_state`、准备转换身份 | `WorldManager` | `[SOURCE]` |
| 玩家控制、相机模式、当前接近运镜 ID | `PlayerVisualManager` 及其子节点 | `[SOURCE]` |
| 战斗激活、输入锁、表现就绪 | `BattleManager` | `[SOURCE]` |
| 逻辑时间、行动队列、待确认行动 | `Timeline` | `[SOURCE]` |
| 玩家与敌人战斗属性 | 各 `CombatEntity.attribute_set` 中的 `Attribute` | `[SOURCE]` |
| 玩家资源回复进度 | `EntityManager` | `[SOURCE]` |
| 敌方行动池、冷却与规划时间 | `EnemyAI` | `[SOURCE]` |
| 抽牌堆、手牌、弃牌堆 | `CardManager` | `[SOURCE]` |
| 单卡战斗 Buff | `RuntimeCard` | `[SOURCE]` |
| 原型玩家与牌组配置 | `PrototypePlayerDataProvider` | `[SOURCE]` |
| 远征结果面板显示状态 | `UISystem` | `[SOURCE]` |
| 存档槽、元数据、模块注册表 | `SaveManager` | `[SOURCE]` |
