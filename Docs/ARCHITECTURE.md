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
| [10. 依赖方向审计](#10-依赖方向审计) | 脚本边界、保留例外与未修复问题 |

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

`PrototypePlayerDataProvider` 把 Inspector 中的原型玩家配置转成 `EntityData` 和 `CardInstance`，让启动交接可以取得明确的输入。它持有原型配置并调用 `AllCardData` 校验 ID，再将对应 `CardData` 注入 `CardInstance.new(id, template)`；数据对象自身不访问 Autoload。战斗激活和运行时牌堆由 Battle 子系统管理。`[SOURCE]`

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
| 输入 | `init_map(blueprint: MapBlueprint = null) -> bool`、`default_blueprint: MapBlueprint`、`DoorSet.door_opened_relay(door)`、`PlayerVisualManager.encounter_approach_finished(transition_id, succeeded)`、`resolve_encounter_request(room_data, should_prepare_battle)`；战斗表现入口 `show_enemy_attack_feedback(source_id)`、`show_enemy_hit_feedback(target_id)`、`show_player_damage_feedback()` |
| 输出 | `encounter_requested(room_data, enemy_id)`、`world_state_changed(previous_state, current_state)`；调用生成器、房间与门装配、玩家表现模式 |
| 数据 | `mapdata`（`rooms` / `doors`）、`current_room_coords`、`current_state`；`RoomData` 保存房间与敌人事实 `[SOURCE]` |

`WorldGenerator.generate(blueprint)` 返回 `rooms` / `doors` 字典；`WorldManager.init_map() -> bool` 检查结构和初始房间，依次检查 `RoomSet.build_rooms() -> bool`、`DoorSet.build_doors() -> bool` 与 `enter_explore_mode() -> bool`。全部完成后才提交 `mapdata` 并进入 `EXPLORE`。`RoomSet` 按 `RoomData.connected_doors` 建立 `BattleRoom`，并保存 RoomData 到实例及接近锚点的索引；`DoorSet` 创建 `Door` 并中继 `door_opened`。`[SOURCE]`

`BattleRoom.build_room() -> bool` 组装四面墙、地板和天花板，`is_assembled` 供创建它的 `RoomSet` 在入树同步 `_ready()` 后检查。有敌人的房间还需要有效敌人 ID、`enemy_root` 和接近锚点；无敌人的房间可以缺少这些表现引用。任一必需组件失败时房间撤下本次挂载；`RoomSet` / `DoorSet` 失败时撤下本批实例。World 收到失败结果后清理两组实例、清空 `mapdata`、通过 `PlayerVisualManager` 停用探索输入并保持 `INIT`；再次进入探索时恢复输入。无门的有效地图不需要门场景。失败日志不替代各层的布尔结果。`[SOURCE]`

`BattleRoom/EnemyRoot/EnemyVisual` 是可选模型表现。`EnemyVisual.gd` 只移动自身的 `MeshInstance3D`，不移动 `EnemyRoot`、碰撞或实体属性；受击和攻击各用短 Tween 返回保存的局部变换，重复事件替换旧 Tween，房间清敌释放节点时终止效果。`[LIVE][SOURCE]`

`report_encounter()` 的 `true` 只表示有效通知已发出，不表示 Battle 已接受。World 保留唯一 pending 请求，直到协调器调用 `resolve_encounter_request()`；不读取监听者的同步处理结果。没有消费者时明确返回 `false`，不留下 pending，也不切换 World 状态。`[SOURCE]`

### `PlayerVisualSystem`

此处是 `WorldSystem/PlayerVisualRoot/PlayerVisual` 的文档分组；真实子场景根节点名为 `PlayerVisual`。它把 World 请求的探索、准备和战斗模式落实到玩家控制与相机，并将接近运镜的完成结果回报 World。`PlayerVisualManager` 及子节点持有表现状态；World 决定当前世界阶段和对应转换身份。`[LIVE][SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `PlayerVisualManager`、`PlayerController`、`HeadController`、`CameraBobMount/DamageShakePivot/PlayerCamera`、`PlayerDamageFeedback`、`DamageOverlay/Flash`、`DebugFreeCamera`；保存于 `ExpeditionSystem/WorldSystem/PlayerVisual/PlayerVisual.tscn` `[LIVE]` |
| 输入 | `change_mode(mode)`、`suspend_after_world_initialization_failure()`、`start_encounter_approach(target, transition_id)`、`cancel_encounter_approach(transition_id)`、`show_damage_feedback()`；玩家运动信号 |
| 输出 | `encounter_approach_finished(transition_id, succeeded)`；更新控制、相机和鼠标模式 |
| 数据 | `current_mode`、当前接近运镜 ID；运动与相机状态由子节点持有 `[SOURCE]` |

`player`、`head`、`player_camera` 是正式模式的必需引用，缺失时 `change_mode()` 在变更控制状态前失败。`bob_mount` 与 `debug_free_camera` 是可选表现；缺少调试相机时调试请求失败并保留原模式，探索和战斗模式仍可用。`[SOURCE]`

`PlayerDamageFeedback` 是可选表现节点：它只驱动行走晃动节点下的独立 `DamageShakePivot` 与不拦截输入的红色 `ColorRect`。重复受伤替换旧 Tween 并恢复基准局部变换；离开战斗模式或节点退出场景树时清理效果。`[LIVE][SOURCE]`

`PlayerCamera/Lantern` 实例来自独立的 `Lantern.tscn`；`LanternGravityPivot/LanternMotionPivot` 下共同承载 `ModelRoot` 与 `LanternLight`，模型通过独立的 `oil_lantern_001_production.tscn` 装配。`PlayerVisualManager` 将 `HeadController.rotation.x` 与已有玩家运动信号分别转发给 `LanternController.set_head_pitch()` 和 `update_movement()`；控制器只驱动有界的俯仰惯性、次级摆动与点燃期间的灯光闪烁，`set_lit(enabled)` 保持灯光开关接口，不持有燃料或其他玩法状态。`[LIVE][SOURCE]`

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

`BattleSystem` 根节点挂 `BattleManager.gd`。`Timeline`、`EnemyAI` 与 `EntityManager` 仍是 `BattleSystem.tscn` 中的内联节点；`CardSystem` 和 `CombatHUD` 在 `UI` 下分别实例化各自的场景。`[LIVE]`

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
   └─ CombatHUD [CombatHUD.tscn]
      └─ Margin
         └─ Columns
            ├─ LeftPanel
            ├─ Spacer
            └─ RightPanel
```

### `BattleManager`

`BattleManager` 是单场战斗的协调入口：接收远征提供的玩家数据、牌组与敌人 ID，初始化实体和卡牌子系统，再连接时间轴行动与结算。它持有战斗激活、结果及输入/表现门闩；逻辑时间、实体属性和牌堆仍由对应子系统持有。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `ExpeditionSystem/BattleSystem/BattleSystem.tscn` 根节点；导出引用绑定 `Timeline`、`EntityManager`、`UI/CardSystem`、`UI`、`UI/CombatHUD` `[LIVE]` |
| 输入 | `start_battle(external_deck, external_player_data, enemy_id) -> bool`、`set_presentation_ready(is_ready) -> bool`、`request_draw_to_full()`、`request_advance_time()`；接收 Card、Timeline、Entity 信号 |
| 输出 | `battle_started`、`battle_ended(is_player_victory)`、`input_lock_changed(is_locked)`、`visual_effect_requested(visual_type, data)`、`enemy_attack_started(source_id, execution_id, effect_id)`、`health_damage_applied(target_id, source_id, amount, execution_id, effect_id)`、`action_presentation_cancelled(execution_id)`；调用 Timeline、EntityManager、CardManager |
| 数据 | `is_battle_active`、`battle_result`、启动与输入锁状态、表现就绪状态、当前行动的表现凭据；`UI.visible` 随激活与表现状态更新 `[SOURCE]` |

`start_battle()` 将 `CardInstance[]` 转为 `RuntimeCard[]`，预检后复位 `Timeline`，依次初始化 `EntityManager` 和 `CardManager`。首次敌方行动必须成功进入时间轴才激活战斗。`EntityManager.entity_died` 触发战斗关闭、`Timeline.cancel_advancement()` 与 `battle_ended`。`[SOURCE]`

必需子系统、实体属性容器、手牌场景和 HUD 控件通过布尔预检；失败时拒绝启动，不继续激活半装配 Battle。`set_presentation_ready(false)` 可在父级初始化交接时早于 Battle 的 `_ready()` 调用，但也校验已保存引用。存档模块可选，非空但缺少 `save_initial_state()` 时警告并跳过快照。`visual_effect_requested` 保留普通表现通知，不参与当前行动的完成门闩。`[SOURCE]`

`BattleManager` 在 `Timeline.action_triggered` 后为该次执行分配单调递增的 `execution_id`，开启表现登记窗口；已确认出牌且仍在播放的卡牌离场、攻击开始和每次实际 HP 损失各登记一个 `effect_id`。`CardManager` 经 `PlayerHandDeck` 报告卡牌离场或移除；`ExpeditionManager` 将战斗表现事件交给 World 组件，并把 Tween 完成或取消回调带回 `notify_visual_completed(execution_id, effect_id)`。玩家受伤组件同时运行镜头与红屏 Tween，两个都结束后才回报一个完成凭据。派发窗口关闭且本次全部凭据归还后，`action_transition_delay`（Inspector 范围 `0–1` 秒，默认 `0.1` 秒）可额外等待，再补排下一次敌方行动并调用 `Timeline.notify_action_finished(action)`。等待期间仍保留原行动的 Timeline 门闩；取消、战斗结束或重启会清空等待令牌，过期计时器不能确认后续行动。没有启动的可选表现立即归还凭据；重复和过期回调被身份检查拒绝。外部取消、死亡、启动失败及重开会清理凭据并取消在途表现。抽牌、悬浮及弃牌动画不属于这次行动的完成门闩。`[SOURCE]`

### `Timeline`

`Timeline` 保存逻辑时间与行动队列，按排期触发 `CombatAction`，再等待同一行动的完成确认；若目标区间仍有下一行动，它从下一帧开始，避免开闸时同帧连发。Battle 通过它统一推进玩家出牌、空等及敌方行动的时间；实体结算和卡牌状态不由时间轴持有。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `BattleSystem/Timeline`；`CombatSystem/Scripts/Timeline.gd` `[LIVE]` |
| 输入 | `add_action(action) -> bool`、`reset_for_battle() -> bool`、`receive_card(runtime_card, source_id, target_id)`、`advance_timeline_to(target_time)`、`notify_action_finished(action)`、`cancel_advancement()` |
| 输出 | `action_triggered(action)`、`time_advanced(delta_time)`、`timeline_data_updated(current_time, action_line)`、`pending_action_changed(is_pending)`、`timeline_advancement_finished`；`get_scheduled_enemy_action_snapshots(horizon)` 返回字典快照 |
| 数据 | `current_time`、`action_line`、`is_advancing`、当前待确认行动；按触发时间、优先级及玩家先序排序 `[SOURCE]` |

### `EntitySystem`

`EntitySystem` 是实体相关代码的概念分组，实际由 `EntityManager`、`CombatEntity` 与 `AttributeSet` 等节点承担。`EntityManager` 用玩家数据和敌人 ID 装配实体，转交到期行动并连接 `EnemyAI`；属性数值保存在各实体的 `Attribute` 中，资源回复进度保存在 `EntityManager`。`[LIVE][SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | 概念分组；`BattleSystem/EntityManager` 下有 `PlayerEntity` 与 `EnemyEntity`，各含 `AttributeSet`；`EntityManager` 引用同级 `EnemyAI` `[LIVE]` |
| 输入 | `initialize(player_data, enemy_id)`、`plan_next_enemy_action(current_timeline_time, source_id)`、`execute_action(action)`、`can_player_afford(cost, resource_name)`、`consume_player_resource(cost, resource_name)`、`advance_player_resource_regeneration(delta_time)` |
| 输出 | `enemy_action_generated(action)`、`visual_effect_generated(visual_type, data)`、`entity_died(entity)`、`health_damage_applied(target_id, source_id, amount)`；`get_enemy_entities()` |
| 数据 | `CombatEntity.attribute_set` 中的 `Attribute` 保存战斗数值；`EntityManager._player_resource_regen_progress` 保存分段回复进度 `[SOURCE]` |

`EntityManager.initialize()` 从 `EntityData` 注册玩家属性，从 `AllEnemyData.get_enemy(enemy_id)` 注册敌人属性并注入 AI 行动池。`CombatEntity.apply_attribute_impact()` 处理属性冲击，负向 `hp` 先扣 `shield`。`[SOURCE]`

`EntityManager.execute_action()` 比较每次 HP 冲击前后的实际生命值，只在确实扣血时发出 `health_damage_applied`；护盾完全吸收的攻击不产生该事件。敌方 `CombatAction.action_type` 来自 `EnemyAction`，`BattleManager` 仅在时间轴触发 `attack` 时发出 `enemy_attack_started`。`ExpeditionManager` 接收两种事件并调用 World 的表现入口；World 按当前 `RoomData.enemy_id` 查找 `BattleRoom/EnemyRoot/EnemyVisual`，或将玩家受伤交给 `PlayerVisualManager`。`EnemyVisual` 在模型归位或取消时回报完成；`PlayerDamageFeedback` 在镜头归位及红屏透明后回报完成。它们不参与伤害、命中及逻辑时间计算。`[SOURCE]`

### `CardSystem`

`CardSystem` 负责战斗内牌组和手牌：`CardManager` 持有抽牌、手牌、弃牌堆并处理卡牌请求，手牌节点负责界面输入。它接收 `BattleManager` 转换后的 `RuntimeCard`；出牌是否可支付以及何时进入时间轴由 `BattleManager` 协调，单卡 Buff 保存在该 `RuntimeCard`。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `BattleSystem/UI/CardSystem` 挂 `CardManager.gd`；子场景含 `PlayerHandDeck`，卡牌节点由 `Card.tscn` 实例化 `[LIVE]` |
| 输入 | `initialize(player_deck: Array[RuntimeCard])`、`draw_cards(amount)`、`confirm_play_card(runtime_card)`、`discard_card(runtime_card)`、`advance_hand_buffs_time(delta_time)`、`set_input_locked(is_locked)`；`PlayerHandDeck.card_play_requested` |
| 输出 | `deck_initialized`、`card_drawn`、`card_play_requested`、`card_played`、`card_play_presentation_completed`、`card_discarded`、`discard_shuffled_into_draw`、`hand_pile_cleared`；更新手牌节点 |
| 数据 | `draw_pile`、`hand_pile`、`discard_pile`；每张 `RuntimeCard.active_buffs` 保存战斗内卡牌 Buff `[SOURCE]` |

### `EnemyAI`

`EnemyAI` 根据 `EntityManager` 注入的行动池与敌我 ID 规划 `CombatAction`，再经 `EntityManager` 和 `BattleManager` 交给 `Timeline` 排期。它持有行动池、冷却和规划时间；敌人属性属于 `CombatEntity`，行动排期属于 `Timeline`。每次请求只规划一个行动；全部技能冷却时从最早可用时刻继续规划。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `BattleSystem/EnemyAI`；`CombatSystem/Scripts/EnemyAI.gd` `[LIVE]` |
| 输入 | `setup_ai(action_pool, entity_id, target_id)`、`plan_initial_actions()`、`plan_next_action(current_timeline_time)` |
| 输出 | `action_planned(action: CombatAction)`；经 `EntityManager.enemy_action_generated` 进入 `Timeline.add_action()` |
| 数据 | `_action_pool`、`_cooldown_tracker`、`_last_planned_time`、施法者与目标 ID `[SOURCE]` |

`EntityManager.initialize()` 调用 `plan_initial_actions()` 生成首个排期行动。之后 `BattleManager` 在敌方行动结算及其表现完成、Battle 仍激活且原行动仍为 Timeline 待确认对象时，经 `EntityManager.plan_next_enemy_action()` 请求补充一个行动，再确认原行动完成，使 `Timeline` 在继续推进时看到新排期。重复行动引用、过期时间与排期失败由 `Timeline.add_action()` 拒绝并返回结果；BattleManager 检查结果，不进行同步重试。当前保存场景只有一个敌人实体；多个独立 AI 实例各自保存冷却与规划指针。`[SOURCE]`

### 战斗 `UI`

战斗 `UI` 展示战斗状态并把手牌操作送往 `CardManager`。`BattleManager` 监听现有子系统信号，合并同一帧更新，向 `CombatHUD.display_state(snapshot)` 下发显示值；HUD 只格式化文本，不连接或查询玩法系统，不保存战斗结束副本。`BattleManager` 决定整层界面显隐，并经 `CardManager.set_input_locked()` 向手牌视图下发输入锁。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `BattleSystem/UI` 为 `CanvasLayer`；`CardSystem` 是原有场景实例，`PlayerInformation` 保持内联，`CombatHUD` 实例化 `ExpeditionSystem/BattleSystem/UI/CombatHUD.tscn`。HUD 场景持有内部布局、样式及四个控件引用；BattleSystem 根节点绑定 `combat_hud` `[LIVE]` |
| 输入 | `BattleManager` 控制 `UI.visible` 并调用 `CombatHUD.display_state(snapshot)`；`PlayerHandDeck` 与 `CardLogic` 接收卡牌数据和输入锁 |
| 输出 | `CardLogic.card_played_request` → `PlayerHandDeck.card_play_requested` → `CardManager.card_play_requested`；`CombatHUD` 刷新玩家、敌人、牌堆、时间轴文本 |
| 数据 | `CombatHUD` 只保留控件与呈现文本；快照仅在本次渲染使用。刷新排队标志属于 `BattleManager`；`PlayerHandDeck` 保存界面输入锁和卡牌节点 `[SOURCE]` |

快照包含 `player`、`enemies`、`piles`、`current_time`、`future_actions`、`scheduled_actions`、`input_allowed`、`is_advancing`、`has_pending_action`、`battle_ended`，只含字典、数组和显示值。实体快照含 ID、名称及 HP/体力/法力与上限；无显式上限时沿用属性初始化值。未来列表仍查询 100 时间单位，下次行动查询仍用原 1000000 范围。未收到快照的独立 HUD 保留场景占位文本。`[SOURCE]`

## 7. 数据结构与生命周期

| 数据链 | 当前转换与持有位置 | 证据 |
| --- | --- | --- |
| `MapBlueprint → WorldGenerator.generate() → mapdata → RoomSet / DoorSet` | `WorldManager.mapdata` 保存 `rooms` / `doors`；两个 Set 创建场景实例 | `[SOURCE]` |
| `RoomData → BattleRoom` | `mapdata.rooms` 的 `RoomData` 传给 `BattleRoom.room_data`；`RoomSet` 保存对象到实例的映射 | `[SOURCE]` |
| `CardData → CardInstance → RuntimeCard → CombatAction` | `AllCardData` 索引模板；provider 按 ID 构造实例；`BattleManager` 用 `card_id` 和 `card_data` 构造运行时卡；`RuntimeCard.create_action()` 生成行动 | `[SOURCE]` |
| `EntityData → CombatEntity → AttributeSet → Attribute` | provider 构造 `EntityData`；`EntityManager.initialize()` 注册玩家实体属性 | `[SOURCE]` |
| `EnemyData / EnemyAction → CombatEntity / EnemyAI → CombatAction` | `AllEnemyData.get_enemy()` 提供属性和行动池；`EntityManager` 装配敌人并启动首轮规划，BattleManager 在行动结算后请求下一次规划 | `[SOURCE]` |
| `RuntimeCard / EnemyAI → CombatAction → Timeline → EntityManager` | 卡牌与 AI 生成行动；Timeline 排期；BattleManager 转交到期行动 | `[SOURCE]` |
| `SaveModule → SaveManager → JSON` | 注册模块提供序列化数据；`SaveManager` 写入 `metadata` / `modules_data`，加载时回调模块 | `[SOURCE]` |

`BattleManager._convert_deck_to_runtime()` 当前使用 `CardInstance.card_id` 与 `card_data`；`CardInstance.modifiers`、`unique_id` 保存在输入实例中。`[SOURCE]`

`CardInstance.new(id, template)` 和 `CardInstance.from_dictionary(data, template)` 都要求创建者注入 ID 匹配的 `CardData`。恢复时保留实例身份并复制修改器；无有效模板的恢复明确失败。`[SOURCE]`

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
| `BattleManager → ExpeditionManager → WorldManager` | `enemy_attack_started(..., execution_id, effect_id)` / `health_damage_applied(..., execution_id, effect_id)` → World 表现入口；完成后 `notify_visual_completed(execution_id, effect_id)` | 已执行攻击与实际扣血对应的可选模型、镜头及屏幕反馈；本次行动全部表现结束后才放行下一行动 `[SOURCE]` |

### 战斗与数据

启动接口把 `external_deck`、`external_player_data` 和 `enemy_id` 一起交给 `BattleManager`：前两项来自 provider 的原型输入，敌人 ID 来自 World 的房间事实。Battle 将牌组转为 `RuntimeCard`，并让 `EntityManager` 按玩家数据和敌人资源建立实体。随后各子系统传递同一个 `CombatAction` 供排期、结算及完成确认；`time_advanced(delta_time)` 将实际流逝时间交给卡牌 Buff 和资源回复的持有者。`[SOURCE]`

| 方向 | 接口与重要参数 | 当前传递 |
| --- | --- | --- |
| `ExpeditionManager → PrototypePlayerDataProvider` | `validate_configuration()`、`get_player_data()`、`get_player_deck()` | `EntityData` 与 `Array[CardInstance]` `[SOURCE]` |
| `ExpeditionManager → BattleManager` | `start_battle(external_deck: Array[CardInstance], external_player_data: EntityData, enemy_id: int) -> bool` | 战斗启动输入和成败结果 `[SOURCE]` |
| `BattleManager → EntityManager / CardManager` | `EntityManager.can_initialize(player_data: EntityData, enemy_id: int)` / `initialize(player_data: EntityData, enemy_id: int)`；`CardManager.can_initialize(player_deck: Array[RuntimeCard])` / `initialize(player_deck: Array[RuntimeCard])` | 玩家实体输入与运行时牌组 `[SOURCE]` |
| `EnemyAI → EntityManager → BattleManager → Timeline` | `action_planned(action)` → `enemy_action_generated(action)` → `add_action(action)` | `CombatAction` `[SOURCE]` |
| `Timeline → BattleManager → EntityManager → EnemyAI` | 敌方 `action_triggered(action)` 结算及表现完成后，`plan_next_enemy_action(current_time, source_id)` → `plan_next_action(current_time)`；成功排期后确认原行动 | 每名敌人至多一个后续排期行动 `[SOURCE]` |
| `CardLogic → PlayerHandDeck → CardManager → BattleManager` | `card_played_request(runtime_card)` → `card_play_requested(runtime_card)` | 当前手牌的 `RuntimeCard` `[SOURCE]` |
| `BattleManager → Timeline` | `receive_card(runtime_card, source_id, target_id)`、`advance_timeline_to(target_time)` | 卡牌行动或空等目标时间 `[SOURCE]` |
| `Timeline → BattleManager → EntityManager` | `action_triggered(action)` → `execute_action(action)` | 到期 `CombatAction` `[SOURCE]` |
| `BattleManager → Timeline` | 全部表现凭据完成后 `notify_action_finished(action)`；战斗结束调用 `cancel_advancement()` | 使用同一行动引用确认结算与表现完成 `[SOURCE]` |
| `PlayerHandDeck → CardManager → BattleManager` | `card_play_exit_finished(runtime_card)` → `card_play_presentation_completed(runtime_card)` | 已确认出牌的卡牌离场完成或被移除后归还该玩家行动的表现凭据 `[SOURCE]` |
| `Timeline → BattleManager → CardManager / EntityManager` | `time_advanced(delta_time)` → `advance_hand_buffs_time(delta_time)` / `advance_player_resource_regeneration(delta_time)` | 实际流逝的逻辑时间段 `[SOURCE]` |
| `CombatEntity → EntityManager → BattleManager` | `entity_died(entity)`；`visual_requested` → `visual_effect_generated` → `visual_effect_requested` | 阵亡实体与表现请求；BattleManager 发出 `battle_ended(is_player_victory)` `[SOURCE]` |
| `BattleManager → CardManager` | 到期行动中遍历 `action.card_buffs`，调用 `apply_buff_to_all_hand_cards(buff)` | 唯一卡牌 Buff 派发入口；EntityManager 只处理实体效果，不再发出 `card_buff_requested` `[SOURCE]` |
| `BattleManager → CombatHUD` | `display_state(snapshot: Dictionary)` | 从各状态持有者复制显示值，不转交模型或管理器引用 `[SOURCE]` |

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
| 战斗激活、输入锁、表现就绪、当前行动的表现完成凭据 | `BattleManager` | `[SOURCE]` |
| 逻辑时间、行动队列、待确认行动 | `Timeline` | `[SOURCE]` |
| 玩家与敌人战斗属性 | 各 `CombatEntity.attribute_set` 中的 `Attribute` | `[SOURCE]` |
| 玩家资源回复进度 | `EntityManager` | `[SOURCE]` |
| 敌方行动池、冷却与规划时间 | `EnemyAI` | `[SOURCE]` |
| 抽牌堆、手牌、弃牌堆 | `CardManager` | `[SOURCE]` |
| 单卡战斗 Buff 列表 | `RuntimeCard`；共享可变 Buff 的计时归属仍待明确 | `[SOURCE]`，见第 10 节 |
| 原型玩家与牌组配置 | `PrototypePlayerDataProvider` | `[SOURCE]` |
| 远征结果面板显示状态 | `UISystem` | `[SOURCE]` |
| 存档槽、元数据、模块注册表 | `SaveManager` | `[SOURCE]` |

## 10. 依赖方向审计

2026-10-19 检查覆盖 49 个项目 `.gd`、16 个 `.tscn`、12 个 `.tres` 及 `project.godot`。第 4–9 节记录主要协调器；下表补充叶节点、非节点对象及遗留路径，合起来构成此次依赖图。`addons/godot-mcp` 的编辑器插件与运行时桥接作为开发基础设施检查其项目接入，不据此保证插件内部全部实现正确。

### 叶节点与数据对象的边界

| 脚本 / 实际生命周期 | 责任、状态和依赖 | 调用 / 信号与依赖性质 |
| --- | --- | --- |
| `WorldGenerator.gd`；WorldSystem 子节点 | 从必需 `MapBlueprint` 和 `AllEnemyData` 索引生成 `RoomData`；临时生成过程状态 | `generate()` 返回 rooms/doors；无反向 World 调用或信号 |
| `RoomSet.gd` / `DoorSet.gd`；WorldSystem 子节点 | 持有生成实例索引；依赖房间/门 PackedScene | `build_rooms() -> bool` / `build_doors() -> bool` 向实例下发数据并清理失败批次；DoorSet 监听 `door_opened` 后中继 |
| `BattleRoom.gd`；RoomSet 创建的 BattleRoom.tscn 根 | 持有 RoomData 引用和表现节点；房间事实属于 RoomData | `build_room() -> bool`、`is_assembled`、`clear_enemies()`；发出 `room_data_changed`；墙/地板/天花板必需，敌人引用按是否有敌人判断 |
| `Door.gd`；DoorSet 创建的 Prefab/Door.tscn 根 | 门的开关与交互状态，持有连接房间信息 | `open_door()` 改变本门并发 `door_opened(self)`；不调用 World |
| `PlayerController.gd`；PlayerVisual/Player | 真实运动、速度、接近运动身份与进度 | 接收 `set_active()` / `start_cinematic_approach()`；必需接近目标和注入的 HeadController；发出运动与接近完成信号 |
| `HeadController.gd`；Player/Head | 俯仰和朝向插值 | 接收 `set_active()` / `smooth_face_world_position()`；父 Node3D 仅用于坐标换算；不调用模式协调器 |
| `CameraBobMount.gd`；Head/CameraBobMount | 相机晃动相位和偏移 | `apply_bob()` 接收运动值；无玩法依赖、信号或权威状态；功能可选 |
| `DebugFreeCamera.gd`；PlayerVisual/DebugFreeCamera | 调试相机输入与速度 | `set_active()` 向下控制；无 World 依赖；功能可选 |
| `CombatEntity.gd`；EntityManager 的两个实体 | ID 与 AttributeSet 引用；实体属性由下级 Attribute 持有 | 必需 AttributeSet；`initialize_from_data()`、`apply_attribute_impact()`、`apply_entity_buff()`；接收 `attribute_updated`，发 `visual_requested` / `entity_died` |
| `EnemyVisual.gd`；BattleRoom 的敌人表现子场景 | 胶囊模型的局部攻击与受击 Tween | 由 WorldManager 根据当前房间调用；效果替换旧 Tween，释放时复位；不读写实体属性 |
| `PlayerDamageFeedback.gd`；PlayerVisual 子节点 | 相机偏移节点与红色屏幕层 | 由 PlayerVisualManager 调用；模式切换、重复事件及退出场景树时复位；不控制玩家移动 |
| `AttributeSet.gd`；每个实体的子节点 | 属性字典和初始值 | 创建 Attribute；中继 `value_changed` 为 `attribute_updated`；可选公式是注入 Callable，无管理器查找 |
| `Attribute.gd` / `AttributeBuff.gd`；RefCounted，AttributeSet/Attribute 持有 | 属性计算值、缓存和修改器；缓存不是独立游戏事实 | 属性操作及 `value_changed`；Buff 只计算数值；不访问场景树或全局服务 |
| `PlayerHandDeck.gd`；CardSystem 子场景 | 卡牌视图列表、输入锁和布局，牌堆权威在 CardManager | 必需 `card_scene: PackedScene`；创建 CardLogic，调用确认/拒绝动画；中继出牌与弃牌意图 |
| `Card_Logic.gd`；动态 Card.tscn 根 | 绑定一张 RuntimeCard，持有显示/动画状态 | 必需内部控件、Interaction/Animation；读单一卡牌模型并监听 `stats_updated`；发出牌/弃牌意图；不改牌堆或玩家资源 |
| `Card_Interaction.gd` / `Card_Animation.gd`；Card.tscn 子节点 | 输入检测 / Tween 生命周期 | 注入通用 Control 目标；调用控件 API、发交互/动画完成信号；不依赖 CardManager、Timeline 或 BattleManager |
| `RuntimeCard.gd` / `CardBuff.gd`；RefCounted，CardManager 牌堆持有 | 战斗卡牌数据与 Buff 列表 / 可变时间次数 | 模板由构造参数注入；`create_action()` 生成 CombatAction；`stats_updated` 通知单卡视图；共享 Buff 风险见下表 |
| `CardInstance.gd`；RefCounted，provider 创建、启动参数持有 | 长期卡牌 ID、模板、修改器、实例身份 | 必需 CardData 注入；序列化不访问 Autoload；无信号。独立于 RuntimeCard 生命周期 |
| `EntityData.gd` / `CombatAction.gd`；RefCounted，由 provider / Card或AI 创建 | 启动属性输入 / 一次行动载荷 | 调用者传入数据；无节点、反向管理器引用或信号；由相应消费方解释 |
| `MapBlueprint.gd` / `RoomData.gd`；Resource，默认配置 / mapdata 持有 | 生成配置 / 房间与敌人事实 | 由 WorldGenerator 创建房间数据，World/BattleRoom 操作；不主动找管理器 |
| `R_carddata.gd` / `R_EnemyData.gd` / `R_EnemyAction.gd`；Resource，目录索引持有 | 卡牌模板 / 敌人模板 / 行动配置 | 由 provider、EntityManager、EnemyAI 向下读取；CardData.play 的旧效果执行路径未接入现行 Battle |
| `SaveModule.gd`；RefCounted，SaveManager 注册表持有 | 通用序列化接口，无玩法事实 | `get_save_data()` / `load_save_data()` / `clear_data()` 由 SaveManager 调用；不要求具体玩法监听者 |
| `BattleSaveModule.gd`；SaveModule 子类，当前未挂载 | 旧战前快照缓存，非现行状态持有者 | 反向调用注入的 save_manager 注册/保存，读取 AllEnemyData；与 Battle 可选 Node 槽接口不兼容，保留为遗留问题 |
| `R_cardeffect.gd`、`E_cost.gd`、`E_Priority.gd`、`E_AddPoison.gd`；Resource 旧效果路径 | 旧卡牌直接修改 source/target | 依赖调用者提供旧字段/方法，现行 RuntimeCard 不调用；迁移范围待单独处理 |
| `PlayerSaveManager.gd`；未挂载空 Node | 无已实现持久化职责 | 无有效依赖或信号；不能视为玩家数据权威 |

### 已修正的确认问题

- HUD 原先同时依赖四个玩法系统并缓存结束标志；现在由现有 BattleManager 下发值快照，HUD 仅持有控件。输入锁经 CardManager 下发给其自有手牌视图。
- CardInstance 原先在构造/恢复时隐式读取 AllCardData；改由 provider/恢复调用者显式注入模板。
- 同一 CombatAction.card_buffs 原先经 EntityManager 信号和 BattleManager 循环各应用一次；删除前一路，保留协调器唯一派发。运行探针复现每张手牌两次，修正后为一次，符合 GAME_DESIGN 的禁止重复结算要求。
- World 的通知返回值原先读取同步监听结果；现在通知与明确 resolve 分开，无消费者也不会悬挂 pending。
- Battle 必需引用错误原先可能仅终止校验函数而继续调用方；现在布尔预检阻止启动。玩家表现的必需控制引用也在模式变更前检查；可选调试相机、存档接口、无监听表现等待均有降级路径。
- World 初始化原先忽略房间、门和房间内部装配失败；现在各同步阶段返回布尔结果，World 检查后才进入探索。失败批次立即从 SceneTree 撤下，不留下可查询的半张地图。

### 保留的合理例外

- EntityManager 注入同级 EnemyAI 是明确装配的下级规划器关系，不因 SceneTree 同级而构成反向依赖；PlayerController 接收 HeadController 也是局部运动组合。
- Timeline 的 `action_triggered` 有明确必需消费者 BattleManager，后者以同一行动调用 `notify_action_finished()`；这是现有具备取消出口的完成协议。Timeline 不读取信号监听者的返回值。
- provider、WorldGenerator、WorldManager、ExpeditionManager 和 EntityManager 对 AllCardData/AllEnemyData 的访问是对低层静态目录的显式依赖；目录不反向访问使用者。数据模型自身已去除该隐藏依赖。
- CardLogic 观察一张 RuntimeCard、通用交互/动画组件操作注入的 Control，以及 Attribute 的计算缓存均有局部责任边界，不能仅凭对象引用判为循环。

### 未修复项与验证边界

| 优先级 / 分类 | 证据与影响 | 后续边界 |
| --- | --- | --- |
| 高 / 确认：共享可变 CardBuff 归属 | `apply_buff_to_all_hand_cards()` 将同一实例加入多张牌，之后各 RuntimeCard 分别修改其 time_left/count_left；移除重复派发并未解决共享计数 | 需先明确每牌独立效果还是整手共享效果；前者逐牌创建状态，后者由一个拥有者推进共享计数。GAME_DESIGN 的 Buff 时机仍待设计，本次不猜测 |
| 中 / 确认：遗留存档反向调用及接口错位 | BattleSaveModule 反向调用存档协调器，且是 RefCounted，无法直接赋给 Battle 的可选 Node 槽，也无 save_initial_state | 当前未挂载；需在存档接入任务中决定注册/快照的上级拥有者，不把旧模块当可用方案 |
| 低 / 确认：旧效果路径 | E_cost 旧路径重复修改 stamina；现行 RuntimeCard 不调用该效果 | 不影响本次实际 Battle 路径；保留迁移/清理任务，未启用旧效果 |
| 待验证：房间缓存 | BattleRoom 缓存 enemy_id；RoomData.is_player_inside 与 World.current_room_coords 缺少统一同步契约 | 当前正常调用保持敌人缓存同步，不能据此断言已发生错误；直接改 Resource 和长期移动流程待验证 |
| 待验证：通用公式与存档异常 | AttributeSet 可注入相互依赖的 Callable；SaveManager 的文件打开/损坏数据失败路径未完整验证 | 当前无公式绑定使用者；不宣称存在已复现循环，不测试或覆盖真实用户存档 |

本轮运行验证覆盖 49 个脚本加载、27 个可用场景/资源加载及序列化 NodePath/导出引用解析；第 16 个旧 `WorldSystem/DebugFreeCamera.tscn` 指向已缺失脚本，属于已记录遗留错误，未计入通过项。Battle 探针覆盖 10 个状态与 30 个事件，并用修改前 HUD 渲染同一运行状态比较文本。实际远征场景覆盖准备运镜、战斗解锁、胜利确认清敌和失败重建；另有必需引用缺失、可选功能降级与异步 resolve 检查。未做像素截图比较、人工连续走门、完整存档恢复或完整 Buff 组合测试。

实现与设计仍有已知差距：当前 `BattleSystem.tscn` 仅装配一个敌人实体和一个 EnemyAI，尚无多敌人战斗场景；provider 每次战斗重新构造玩家数据，尚非跨战斗持久玩家属性。多个独立 AI 的时间状态已做隔离探针，不能代替完整多敌人场景验证。
