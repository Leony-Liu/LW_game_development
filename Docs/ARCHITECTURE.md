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

审计日期：2026-10-28。本次从真实文件复核配置、场景接线、52 个项目脚本及内容生产链；有限 headless 验证的范围、已知失败路径和限制见第 12 节。本文不是完整依赖图或完整游戏验收记录。

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
| [11. 内容生产就绪评估](#11-内容生产就绪评估) | 增量内容任务的可用范围与阻塞 |
| [12. 本次验证记录](#12-本次验证记录) | 2026-10-28 的实际证据与未验证范围 |

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
MainMenu（主场景，Control；MainMenu.gd）

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

`project.godot` 保存 Forward Plus、1920×1080 UI 基准、1280×720 窗口覆盖和 `canvas_items/expand` 拉伸，以及全局 Theme/字体 UID。战斗通过 InputMap 的 `combat_draw_to_full`（F）、`combat_advance_time`（Space）接收操作；探索 PlayerController 与门/调试相机仍直接读取 WASD、Shift、E 等按键。已有 InputMap 项不能单凭名称视作对应玩法已实现或已支持重绑定。`[LIVE][SOURCE]`

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

`MainMenu` 提供项目配置的场景入口，用可编辑的居中容器显示“开始游戏”和“退出游戏”，复用全局 Theme/字体；不承载远征、存档或战斗状态。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `MainMenuSystem/MainMenu.tscn`；`Control` 根挂载 `MainMenu.gd`，内部 CenterContainer / VBoxContainer / 两个 Button `[SOURCE]` |
| 输入 | `project.godot` 的 `run/main_scene` 指向该场景 |
| 输出 | Start 的保存信号连接调用 `SceneTree.change_scene_to_file("res://BaseSystem/Base.tscn")` 并检查 Error；失败时报告错误并保留菜单。Quit 调用 `SceneTree.quit()` `[SOURCE]` |

主场景 UID 保持 `uid://cu8ebs30en5qs`。`BaseSystem/Base.tscn` 已存在且经菜单运行加载验证，当前包含 Field 和 Interactive items，没有基地交互、整备或 Base-to-Expedition 切换。GameManager 尚无应用流程 API，因此本次入口操作保留在 MainMenu 脚本，不新增管理器。远征玩法验证仍直接运行 `ExpeditionSystem/ExpeditionSystem.tscn`。`[SOURCE][VERIFY]`

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

目前目录有 7 个卡牌模板、2 个敌人模板；加载器只扫描目录这一层。AllCardData 读取 `.tres`，AllEnemyData 同时处理 `.tres` / `.res` / `.remap`。两者均以 ID 直接覆盖字典项，没有重复 ID 拒绝机制；新增内容须核对唯一 ID。卡牌导出包的资源重映射发现能力本次未验证。`[SOURCE][VERIFY]`

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

`WorldGenerator.generate(blueprint)` 返回 `rooms` / `doors` 字典；`WorldManager.init_map() -> bool` 检查结构和初始房间，依次检查 `RoomSet.build_rooms() -> bool`、`DoorSet.build_doors() -> bool`，再赋值 `mapdata` 并调用 `enter_explore_mode() -> bool`；探索切换失败时回滚清空地图。`RoomSet` 按 `RoomData.connected_doors` 建立 `BattleRoom`，并保存 RoomData 到实例及接近锚点的索引；`DoorSet` 创建 `Door` 并中继 `door_opened`。`[SOURCE]`

Blueprint 当前配置房间数/浮动、Boss 配额、遇敌/精英概率和类型权重。RoomData 只定义 `INITIAL/NORMAL`；所有房间均由一个 `battle_room_scene` 装配，尚无设施房或按类型选房间预制体的路径。生成器按 `EnemyData.enemy_level` 抽敌人（0 普通、1 精英、2 Boss）；现有两个模板为 0/1，默认 `boss_count = 0`。启用 Boss 配额前须提供 level 2 模板，否则生成 `has_enemies = true, enemy_id = -1`，敌人房装配会失败。10 米网格和形状偏好仍为代码常量，World 的开门推算也使用 10 米网格。`[SOURCE]`

`BattleRoom.build_room() -> bool` 组装四面墙、地板和天花板，`is_assembled` 供创建它的 `RoomSet` 在入树同步 `_ready()` 后检查。有敌人的房间还需要有效敌人 ID、`enemy_root` 和接近锚点；无敌人的房间可以缺少这些表现引用。任一必需组件失败时房间撤下本次挂载；`RoomSet` / `DoorSet` 失败时撤下本批实例。World 收到失败结果后清理两组实例、清空 `mapdata`、通过 `PlayerVisualManager` 停用探索输入并保持 `INIT`；再次进入探索时恢复输入。无门的有效地图不需要门场景。失败日志不替代各层的布尔结果。`[SOURCE]`

`BattleRoom/EnemyRoot/EnemyVisual` 是可选模型表现。`EnemyVisual.gd` 只移动自身的 `MeshInstance3D`，不移动 `EnemyRoot`、碰撞或实体属性；受击和攻击各用短 Tween 返回保存的局部变换，重复事件替换旧 Tween，房间清敌释放节点时终止效果。`[LIVE][SOURCE]`

`report_encounter()` 的 `true` 只表示有效通知已发出，不表示 Battle 已接受。World 保留唯一 pending 请求，直到协调器调用 `resolve_encounter_request()`；不读取监听者的同步处理结果。没有消费者时明确返回 `false`，不留下 pending，也不切换 World 状态。`[SOURCE]`

当前“进入房间”的事实在门打开动画完成后，通过门与玩家相对位置推算，并立即更新 `current_room_coords`；并非玩家穿越门面的检测。`entry_direction` 在生成房间时赋值，当前走门不刷新；`is_player_inside/nearby` 也没有活动调用方同步。它们不能直接充当已实现的 Room Entry Checkpoint。`[SOURCE]`

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
   └─ CombatHUD [CombatHUD.tscn]
      ├─ EnemyStatus
      ├─ PlayerInformation
      └─ ActionButtons
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

保存值覆盖脚本默认值：`BattleSystem.tscn` 为 `0.4` 秒，远征实例再次覆盖为 `0.5` 秒。替换异步反馈必须保留成功、取消与释放时的完成回报；当前没有“回调丢失后自动超时放行”的通用机制。上述延迟与 Tween 只影响现实等待，逻辑时间仍由 Timeline 决定。`[LIVE][SOURCE]`

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

当前初始化/AI/目标查找都只配置一个敌人；`get_enemy_entities()` 的枚举并不提供多敌人装配。`_get_entity_by_id()` 还把任意 `enemy_` 前缀映射到这个唯一实体。实体 Buff 当前统一作用于 `hp`，没有从载荷选择其他属性的契约。敌人要获得护盾，须在 `EnemyData.attributes` 中显式定义 `shield`，否则通用属性冲击不会创建该属性。`[SOURCE]`

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

`EnemyAction` 当前在两个敌人 `.tres` 内作为子资源编辑；支持配置时间、冷却、权重和 `effect_data`。AI 的 `attack` 读取 `damage`（缺省 10），`buff` 读取 `shield` 并以自身为目标，`skill` 仍为 `pass`；行动 priority 固定为 1。预检拒绝空池、空行动、非正 time_cost 与负 cooldown，但未校验 action_id 唯一性、权重或效果字典模式。后续补排失败会记录错误并确认原行动，不会自动结束 Battle 或恢复敌方行动链。`[SOURCE]`

### 战斗 `UI`

战斗 `UI` 展示战斗状态并把手牌操作送往 `CardManager`。`BattleManager` 监听现有子系统信号，合并同一帧更新，向 `CombatHUD.display_state(snapshot)` 下发显示值；HUD 只更新自身控件，不连接或查询玩法系统，不保存战斗结束副本。`BattleManager` 决定整层界面显隐，并经 `CardManager.set_input_locked()` 向手牌视图下发输入锁。`[SOURCE]`

| 项目 | 当前实现 |
| --- | --- |
| 位置与组成 | `BattleSystem/UI` 为 `CanvasLayer`；`CardSystem` 是原有场景实例，`PlayerInformation` 位于 `CombatHUD.tscn` 内，取代父场景中原本空置的同名节点。HUD 场景持有敌人血条、玩家生命与资源标记、未来行动图标模板及只读提示框、抽牌、弃牌、推进按钮；BattleSystem 根节点绑定 `combat_hud` `[LIVE]` |
| 输入 | `BattleManager` 控制 `UI.visible` 并调用 `CombatHUD.display_state(snapshot)`；HUD 三按钮向 `BattleManager` 发出操作意图；`PlayerHandDeck` 与 `CardLogic` 接收卡牌数据、弃牌模式和输入锁 |
| 输出 | `CardLogic.card_played_request` → `PlayerHandDeck.card_play_requested` → `CardManager.card_play_requested`；卡牌悬停由 `Card_Interaction` 检测，经 `CardLogic.hover_changed`、`PlayerHandDeck.card_hover_changed`、`CardManager.card_hover_changed` 通知 `BattleManager`；弃牌请求经 `PlayerHandDeck` 到 `CardManager.discard_card()`，成功后 `card_discarded` 通知 `BattleManager` 退出模式；HUD 刷新玩家与敌人状态及未来行动图标 |
| 数据 | `CombatHUD` 只保留控件引用、按钮显示状态、当前悬停图标的显示身份及预览中的行动实例 ID；行动图标保存对应快照的实例标识与显示字段作为节点元数据。`CombatHUD.hide_intent_tooltip()` 和 `clear_intent_preview()` 分别清除提示框和预览。弃牌模式由 `PlayerHandDeck` 持有并向各卡牌视图下发；`BattleManager` 协调按钮、输入锁、模式结束及只读悬停预览。`CardManager` 仍持有牌堆，且只在手牌区下方的空白点击时发出取消通知。刷新排队标志属于 `BattleManager` `[SOURCE]` |

快照包含 `player`、`enemies`、`piles`、`current_time`、`future_actions`、`preview_action_ids`、`scheduled_actions`、`input_allowed`、`is_advancing`、`has_pending_action`、`battle_ended`，只含字典、数组和显示值。实体快照含 ID、名称及 HP/体力/法力与上限；无显式上限时沿用属性初始化值。`future_actions` 继续使用 100 时间单位窗口，行动条目包含 `action_instance_id`（本次运行中的 `CombatAction` 实例标识）、`source_id`、`action_name`、`action_type`、`trigger_time`、`relative_time` 和 `priority`；攻击的明确负向 HP 冲击另提供 `base_damage`，增益的明确正向护盾冲击另提供 `shield_gain`，均为可选显示值。`BattleManager` 用悬停 `RuntimeCard.get_time_cost()` 与 `get_priority()` 和当前 `future_actions` 计算本次时间推进可到达的实例 ID；Timeline 的目标时间含边界，同刻优先级只改变结算先后。`CombatHUD` 仅按这些 ID 缩放已有可见图标，弃牌模式、输入锁及战斗关闭会清除预览。HUD 用首个敌人快照绘制顶部血条及对应行动图标，悬停时依实例标识显示名称、类型、时间及已有数值，并随鼠标移动且保持在视口内；在圆盘内显示玩家当前/最大 HP 与资源数值，用四格菱形明暗表达资源比例。未收到快照的独立 HUD 保留场景占位值。`[SOURCE]`

## 7. 数据结构与生命周期

| 数据链 | 当前转换与持有位置 | 证据 |
| --- | --- | --- |
| `MapBlueprint → WorldGenerator.generate() → mapdata → RoomSet / DoorSet` | `WorldManager.mapdata` 保存 `rooms` / `doors`；两个 Set 创建场景实例 | `[SOURCE]` |
| `RoomData → BattleRoom` | `mapdata.rooms` 的 `RoomData` 传给 `BattleRoom.room_data`；`RoomSet` 保存对象到实例的映射 | `[SOURCE]` |
| `CardData → CardInstance → RuntimeCard → CombatAction` | `AllCardData` 索引模板；provider 按 ID 构造实例；`BattleManager` 用 `card_id`、`card_data`、`unique_id` 构造运行时卡；`RuntimeCard.create_action()` 生成行动 | `[SOURCE]` |
| `EntityData → CombatEntity → AttributeSet → Attribute` | provider 构造 `EntityData`；`EntityManager.initialize()` 注册玩家实体属性 | `[SOURCE]` |
| `EnemyData / EnemyAction → CombatEntity / EnemyAI → CombatAction` | `AllEnemyData.get_enemy()` 提供属性和行动池；`EntityManager` 装配敌人并启动首轮规划，BattleManager 在行动结算后请求下一次规划 | `[SOURCE]` |
| `RuntimeCard / EnemyAI → CombatAction → Timeline → EntityManager` | 卡牌与 AI 生成行动；Timeline 排期；BattleManager 转交到期行动 | `[SOURCE]` |
| `SaveModule → SaveManager → JSON` | 注册模块提供序列化数据；`SaveManager` 写入 `metadata` / `modules_data`，加载时回调模块 | `[SOURCE]` |

`BattleManager._convert_deck_to_runtime()` 将 `CardInstance.unique_id` 传给 `RuntimeCard.source_instance_uid`。模板数字 ID、Godot Resource UID 和卡牌实例 UID 是不同身份；同模板的具体卡具有不同实例 UID。`RuntimeCard` 不生成来源身份，无实例来源时允许空字符串。`CardInstance.modifiers` 仍只保存在输入实例中，未参与 runtime 属性计算；转换语义待设计，本次未自动映射到 Buff。`[SOURCE]`

`CardInstance.new(id, template, instance_uid = "")` 和 `CardInstance.from_dictionary(data, template)` 都要求注入 ID 匹配的 `CardData`。新身份由 `Crypto.generate_random_bytes(32)` 生成 256 位随机十六进制字符串；恢复时原样保留有效旧字符串，仅缺失、空白或非字符串 UID 才生成替代并警告。修改器继续深拷贝，无有效模板的恢复明确失败。两类卡牌的 dictionary API 保留各自 UID 字段；RuntimeCard 两参数构造和缺来源字段的旧字典仍兼容。未接通存档管线。`[SOURCE]`

### 静态武器模板基础

`Scripts/Resource/Weapon/R_weapondata.gd` 定义 `WeaponData extends Resource`，只导出 `id`、`name`、`description`。`Scripts/WeaponData/Weapons/ExampleWeapon.tres` 是 ID 1 的元数据示例，可通过 `ResourceLoader.load()` 读取为 WeaponData。当前无武器查询消费者，因此不创建 registry 或 Autoload；示例不代表可玩武器。Weapon = Deck 的方向保持不变，具体牌组字段/序列化、装备和 runtime 转换尚未建立。`[SOURCE]`

### 内容创建与消费的实际边界

- 卡牌模板在 `Scripts/CardData/Cards/` 创建，经索引和 provider 的 `prototype_card_ids` 进入当前测试牌组；新增模板不会自动加入牌组。`RuntimeCard.create_action()` 仅生成伤害与可选 `shield` 数值冲击；`CardData` Resource 本身没有导出 `shield` 字段。`effects` 虽复制进 runtime 字典，但现行执行链不调用 `CardData.play()` / `CardEffect.execute()`，也没有模板到 `card_buffs/entity_buffs` 的转换。`[SOURCE]`
- 现有“蓄力”“崩势步”“致命斩击”“迅跃斩”的描述包含下一次增伤或增伤比例，但这些描述不是效果实现证据；现有模板也没有接通相应 Buff。不能把增加文本或填充旧 effects 当作新机制已完成。`[SOURCE]`
- `get_resource_cost()` 对 Attack 取 stamina_cost、其他类型取 mana_cost，但 Battle 的出牌预检和扣费都写死使用 `stamina`。这是确认的显示/执行资源语义不一致；最终类型默认资源规则仍属 GAME_DESIGN 的待设计项。`[SOURCE]`
- 计数 Buff 在 `CardManager.confirm_play_card()` 内消耗，早于 `Timeline.receive_card()` 创建行动；持续时间只由 `advance_hand_buffs_time()` 推进当前手牌。此处记录当前顺序，不将其确认为最终 Buff 规则。`[SOURCE]`
- provider 每次遭遇都创建新的 EntityData 与 CardInstance；实体状态变化没有写回 provider 的路径。CardInstance 的“长期”是对象设计能力，当前没有武器牌组拥有者、跨战斗 HP 继承或持久保存接入。`[SOURCE][PLACEHOLDER]`

### 存档接口的当前兼容性

`BattleSaveModule` 的玩家字段已与当前 EntityData 对齐，敌人恢复也会查模板取得行动池；旧文档关于字段/构造签名仍全面不兼容的结论已失效。但该类继承 `SaveModule/RefCounted`，当前没有实例化/注册调用链，不能赋给 Battle 的 `battle_save_module: Node`，也没有其要求的 `save_initial_state()`；`_compile_input_to_runtime()` 仍为空，`input_deck = [CardInstance]` 不是有效具体牌组。`RuntimeCard.to_dictionary()` 亦未覆盖临时 Buff。`[SOURCE][LEGACY]`

遗留 `BattleSaveModule.load_save_data()` 仍手工以两参数构造 RuntimeCard，未调用其 `from_dictionary()`，因此也不恢复新增来源 UID；该路径未启用，本次按存档暂停边界保留，不将新的 dictionary 契约宣称为完整存档兼容。`[SOURCE][LEGACY]`

遗留 `BattleSaveModule.load_save_data()` 仍手工以两参数构造 RuntimeCard，未调用其 `from_dictionary()`，因此也不恢复新增来源 UID；该路径未启用，本次按存档暂停边界保留，不将新的 dictionary 契约宣称为完整存档兼容。`[SOURCE][LEGACY]`

SaveManager 可提供模块式 JSON I/O，但不等于当前游戏已有 checkpoint。GAME_DESIGN 已确认 Room Entry / Battle Start Checkpoint 与 Battle 中断后整场重开，精确保存 Battle 中间队列已非待决需求；实现仍未接通。存档开发按 README 暂缓，只有用户明确恢复时再处理接入、失败结果及格式兼容。`[SOURCE][PLACEHOLDER]`

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

2026-10-28 复核非 addons 项目的 52 个 `.gd`、22 个 `.tscn`、12 个 `.tres` 及 `project.godot`；检查主要方法、调用、信号、数据构造和保存引用。第 4–9 节记录主要协调器，下表补充叶节点和数据对象。覆盖不等于枚举所有动态 Callable、所有资源内嵌关系或证明不存在循环；`addons/godot-mcp` 只核对项目接入及运行桥端口，不保证插件内部实现正确。

### 叶节点与数据对象的边界

| 脚本 / 实际生命周期 | 责任、状态和依赖 | 调用 / 信号与依赖性质 |
| --- | --- | --- |
| `WorldGenerator.gd`；WorldSystem 子节点 | 从必需 `MapBlueprint` 和 `AllEnemyData` 索引生成 `RoomData`；临时生成过程状态 | `generate()` 返回 rooms/doors；无反向 World 调用或信号 |
| `RoomSet.gd` / `DoorSet.gd`；WorldSystem 子节点 | 持有生成实例索引；依赖房间/门 PackedScene | `build_rooms() -> bool` / `build_doors() -> bool` 向实例下发数据并清理失败批次；DoorSet 监听 `door_opened` 后中继 |
| `BattleRoom.gd`；RoomSet 创建的 BattleRoom.tscn 根 | 持有 RoomData 引用和表现节点；房间事实属于 RoomData | `build_room() -> bool`、`is_assembled`、`clear_enemies()`；发出 `room_data_changed`；墙/地板/天花板必需，敌人引用按是否有敌人判断 |
| `Door.gd`；DoorSet 创建的 Prefab/Door.tscn 根 | 门的开关、附近玩家与 Tween 状态；不持有连接房间 ID | `open_door()` 动画结束后发 `door_opened(self)`；不调用 World |
| `PlayerController.gd`；PlayerVisual/Player | 真实运动、速度、接近运动身份与进度 | 接收 `set_active()` / `start_cinematic_approach()`；必需接近目标和注入的 HeadController；发出运动与接近完成信号 |
| `HeadController.gd`；Player/Head | 俯仰和朝向插值 | 接收 `set_active()` / `smooth_face_world_position()`；父 Node3D 仅用于坐标换算；不调用模式协调器 |
| `CameraBobMount.gd`；Head/CameraBobMount | 相机晃动相位和偏移 | `apply_bob()` 接收运动值；无玩法依赖、信号或权威状态；功能可选 |
| `DebugFreeCamera.gd`；PlayerVisual/DebugFreeCamera | 调试相机输入与速度 | `set_active()` 向下控制；无 World 依赖；功能可选 |
| `CombatEntity.gd`；EntityManager 的两个实体 | ID 与 AttributeSet 引用；实体属性由下级 Attribute 持有 | 必需 AttributeSet；`initialize_from_data()`、`apply_attribute_impact()`、`apply_entity_buff()`；接收 `attribute_updated`，发 `visual_requested` / `entity_died` |
| `EnemyVisual.gd`；BattleRoom 的敌人表现子场景 | 胶囊模型的局部攻击与受击 Tween | 由 WorldManager 根据当前房间调用；效果替换旧 Tween，释放时复位；不读写实体属性 |
| `PlayerDamageFeedback.gd`；PlayerVisual 子节点 | 相机偏移节点与红色屏幕层 | 由 PlayerVisualManager 调用；模式切换、重复事件及退出场景树时复位；不控制玩家移动 |
| `LanternController.gd`；PlayerCamera 下 Lantern 子场景根 | 可选提灯的俯仰弹簧、运动摆动和灯光状态；内部 pivots/light 必需 | `set_head_pitch()`、`update_movement()`、`set_lit() -> bool`；只接受 PlayerVisualManager 下发数据，不持有 Fuel |
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

### 旧审计问题的当前状态

- 当前 HUD 无玩法系统导出引用，由 BattleManager 下发值快照；手牌输入锁经 CardManager 下发。`[SOURCE]`
- CardInstance 构造/恢复要求显式模板，不再隐式读取 AllCardData。`[SOURCE]`
- 当前只有 BattleManager 派发 `action.card_buffs`，EntityManager 无重复派发信号；共享可变状态问题仍存在，见下表。此项本轮为源码复核，未重跑旧重复结算探针。`[SOURCE]`
- World 通知与 resolve 分开，无消费者时不登记 pending；Battle 与地图装配关键入口检查布尔结果，World 失败时清理地图。PlayerVisual 正式模式校验必需引用，可选功能具有局部降级路径。`[SOURCE]`
- BattleSaveModule 的 EntityData 字段/构造方式已对齐；保留真实的未挂载、类型、方法和转换缺口，见第 7 节。`[SOURCE]`

### 保留的合理例外

- EntityManager 注入同级 EnemyAI 是明确装配的下级规划器关系，不因 SceneTree 同级而构成反向依赖；PlayerController 接收 HeadController 也是局部运动组合。
- Timeline 的 `action_triggered` 有明确必需消费者 BattleManager，后者以同一行动调用 `notify_action_finished()`；这是现有具备取消出口的完成协议。Timeline 不读取信号监听者的返回值。
- provider、WorldGenerator、WorldManager、ExpeditionManager 和 EntityManager 对 AllCardData/AllEnemyData 的访问是对低层静态目录的显式依赖；目录不反向访问使用者。数据模型自身已去除该隐藏依赖。
- CardLogic 观察一张 RuntimeCard、通用交互/动画组件操作注入的 Control，以及 Attribute 的计算缓存均有局部责任边界，不能仅凭对象引用判为循环。

### 未修复项与验证边界

| 优先级 / 分类 | 证据与影响 | 后续边界 |
| --- | --- | --- |
| 高 / 确认：共享可变 CardBuff 归属 | `apply_buff_to_all_hand_cards()` 将同一实例加入多张牌，之后各 RuntimeCard 分别修改其 time_left/count_left；当前模板未产生该载荷，属于扩展入口的确认风险，非本轮默认牌组故障复现 | 需先明确每牌独立效果还是整手共享效果；前者逐牌创建状态，后者由一个拥有者推进共享计数。GAME_DESIGN 的 Buff 时机仍待设计，本次不猜测 |
| 高 / 确认：卡牌内容消费与资源语义缺口 | 第 7 节：effects 未接入、增伤描述无对应载荷、mana_cost 计算后仍扣 stamina；当前模板无法表达所有已写描述 | 批量生产新机制/非 Attack 卡前先明确资源规则并安排单独实现任务；不是要求本轮重构 |
| 高 / 确认：跨战斗数据缺失 | provider 每场重新创建输入，ExpeditionManager 只接收胜负，无 HP/牌组写回；与已确认跨战斗 HP 目标有差距 | 在远征成长内容前明确状态输入/结果写回契约；保留原型配置职责 |
| 中 / 确认：遗留存档反向调用及接口错位 | BattleSaveModule 反向调用存档协调器，且是 RefCounted，无法直接赋给 Battle 的可选 Node 槽，也无 save_initial_state | 当前未挂载；需在存档接入任务中决定注册/快照的上级拥有者，不把旧模块当可用方案 |
| 中 / 确认：输入校验和失败处置不完整 | 重复模板 ID 直接覆盖；AI 不校验权重/action_id 唯一性，补排失败仅报错并继续；ExpeditionManager/结果 UI 必需引用仍主要用 assert | 新内容先做 ID/行动池/引用校验；独立任务补关键失败策略，本轮未运行故障注入或 Release 验证 |
| 低 / 确认：旧效果路径 | E_cost 旧路径重复修改 stamina；现行 RuntimeCard 不调用该效果 | 不影响本次实际 Battle 路径；保留迁移/清理任务，未启用旧效果 |
| 低 / 确认：失效场景 | `ExpeditionSystem/WorldSystem/DebugFreeCamera.tscn` 引用缺失脚本，未被活动远征引用；两个 `.tmp` 为旧接线 | 不作为新内容入口；独立清理任务处理，不以加载器成功掩盖该路径 |
| 待验证：房间缓存与实体复用 | BattleRoom 缓存 enemy_id；World 只更新 current_room_coords，未同步 inside/entry；EntityManager 逐键注册敌人属性，没有清空上场独有属性的入口 | 静态可见同步/重置缺口；新房间事件和不同属性敌人连续战斗需针对性运行验证，不宣称当前已复现玩家错误 |
| 确认静态缺口 / 故障未运行：存档 I/O | `load_slot()` 未检查 FileAccess.open 是否为 null，缺失文件不发 load_finished(false)，JSON 根类型未校验；模块 load 无成功结果契约 | 暂停路径，未测试或覆盖用户存档；恢复开发后用隔离数据验证失败及部分恢复处置 |
| 待验证：公式依赖和替换表现 | AttributeSet 允许相互依赖 Callable，当前无绑定调用方；已登记效果若漏回调没有超时兜底 | 不把潜在公式循环或未制作表现视为已复现缺陷；新增效果验证完成/取消/释放 |

实现与设计仍有差距：当前一个敌人实体与一个 EnemyAI，不能把多个独立 AI 的状态隔离等同于完整多敌人 Battle。第 6 节已核对单敌人的装配、目标别名、补排与 HUD 首敌显示约束，本轮未运行多 AI 或多敌人测试。

## 11. 内容生产就绪评估

结论：当前结构能支持“明确需求 → 小范围实现 → 窄范围验证 → 人工审阅”的原型增量迭代；已有数值内容、HUD 和反馈替换路径可定位。但尚不能把完整远征成长、新 Buff/技能、多敌人或试玩版全功能视为现成内容生产管线。Web GPT 应从下表与 CODEMAP 选路，任务中明确数据字段、影响边界、待决项和验收证据，Codex 再核对所涉真实文件；不必每次重建全仓依赖图。

就绪等级仅适用于表内的扩展范围：`Ready` 表示已有实现/契约与足够证据支持该扩展；`Ready with constraints` 表示可以扩展但必须遵守已列限制；`Not ready` 表示确认缺口阻碍该范围；`Not verified` 表示证据不足，不等于确认缺陷。

| 内容 / 关注点 | 已核实实现路径 | 就绪等级 | 证据与实际限制 | 建议下一步 |
| --- | --- | --- | --- | --- |
| 普通伤害卡数值与文本 | CardData → AllCardData → provider → RuntimeCard → CombatAction | Ready with constraints | 模板/牌组加载及 Battle 启动已验证；唯一 ID、手工加入原型牌组；旧 effects 不执行，描述须匹配真实伤害 | 只在现有字段内出任务；单卡验证实际伤害/扣费/时间 |
| 新卡牌机制、计次/持续 Buff | CombatAction.card_buffs → BattleManager → CardManager → RuntimeCard | Not ready | API 存在，但无模板载荷转换，共享可变 Buff 与 confirm 前后消耗语义未定 | 先确认 Buff 归属/时机与资源分类，再实现一个机制切片 |
| 单敌人类型、攻击数值与冷却 | EnemyData / EnemyAction → EntityManager / EnemyAI → Timeline | Ready with constraints | 两个模板加载；现有敌人首次攻击/冷却补排已运行；attack/shield 分支有限，权重和 ID 需人工校验 | 新模板先验证属性、行动池、地图等级可选性与连续战斗复用 |
| 特殊敌方 skill / 多敌人 Battle | EnemyAI.skill；BattleSystem 单敌人装配 | Not ready | skill 为 pass；固定目标、实体和 HUD 首敌约束，枚举 API 不能弥补装配缺口 | 各自单独定义范围，不能仅新增 .tres 或复制 AI 节点 |
| 地图参数、现有房间外观 | MapBlueprint → WorldGenerator → RoomSet / DoorSet → BattleRoom / Prefab | Ready with constraints | 默认地图已生成并装配；一套房间结构、固定网格；Boss 需要 level 2 模板 | 参数任务先检查敌人等级供给；外观任务保留根类型/挂载点/锚点 |
| 设施房、任务/奖励与独立遭遇规则 | RoomData 当前仅 INITIAL/NORMAL 和单 enemy_id | Not ready | 没有相关创建/消费链；开门推算也不等于入口 checkpoint | 按已确认设计逐项定义房间事件与状态契约，不预造管理层 |
| 替换敌人/玩家战斗反馈 | Battle 事件 → ExpeditionManager → World → EnemyVisual / PlayerDamageFeedback | Ready with constraints | 游戏事实与表现分离，模型/pivots/覆盖层可编辑；本轮未运行 Tween 视觉/取消验收，必须归还完成凭据 | 保持布尔启动结果与完成/取消回报；验收不改逻辑时间和伤害 |
| HUD、卡牌视觉与局部布局 | BattleManager._refresh_hud() → CombatHUD.display_state()；Card.tscn / Animation | Ready with constraints | 引用与初始化通过；HUD 不查询玩法系统，手牌只观察单卡；首敌显示、字段契约与卡牌离场凭据有约束 | 布局先改所属场景；新显示字段由协调器提供，补目标分辨率与交互验收 |
| 提灯模型/光照的 Inspector 调整 | PlayerVisual → LanternController → gravity/motion pivots / model scene | Ready with constraints | 独立场景和导出参数、引用可解析；没有 Fuel owner，俯仰/移动观感未在本轮验证 | 保留表现职责，替换后人工检查低头和移动 |
| 远征成长、跨战斗 HP/牌组、基地循环 | provider 每场新建数据；MainMenu 可进入 Base，GameManager 仍为空；WeaponData 只有元数据 | Not ready | 缺 Base-to-Expedition、状态写回、武器/经济/任务/Fuel 等活动消费链，与设计目标有明确差距 | 优先小范围建立远征玩家数据输入/写回契约；不要把 provider 当长期权威 |
| checkpoint / 长期存档 | SaveManager / SaveModule；BattleSaveModule 遗留 | Not ready | 无业务注册/恢复入口，接口错位；README 明确暂缓 | 等用户恢复开发，再按已确认 checkpoint 边界接入 |
| 导出包资源发现与发布运行 | 目录加载器 → 导出资源 remap | Not verified | 本轮仅本地编辑器二进制 headless；无导出构建或包内扫描证据 | 发布相关任务再验证，不能从本地加载成功推导 |
| 当前原型玩家参数调整 | provider Inspector → EntityData → start_battle | Ready | 字段映射、有效模板注入、配置与 Battle 启动已验证；结论仅限原型输入数值调整 | 保留每场重新构造的明确边界 |

从八项架构维度看：

| 维度 | 当前判断 |
| --- | --- |
| 所有权与模块边界 | World/Battle/Card/Entity/Timeline 的主要责任可追踪，原型 provider 与长期数据之间仍有缺口；合理同级注入见第 10 节 |
| 数据驱动 | 基础卡牌、敌人行动、地图概率可配置；新效果转换、房型行为、资源路由仍需代码任务 |
| 局部扩展成本 | 现有数值/视觉通常局部修改；新机制需沿 producer → CombatAction → consumer 核对，不能假设 effects 是扩展接口 |
| 权威状态与表现分离 | HUD 快照、卡牌意图信号、战斗表现凭据已有明确入口；完成协议仍须由替换组件遵守 |
| 场景/资源可编辑与可替换 | HUD、卡牌、敌人表现、提灯独立可编辑；Timeline/AI 等内联逻辑节点无需为形式拆场景 |
| 可发现性与公共契约 | CODEMAP 提供任务最小起点，第 5–8 节提供参数/结果/信号；动态字典字段仍需在生产者和消费者两端检查 |
| 窄范围验证 | CLI、资源加载和临时探针可用；没有可直接重跑全部旧审计场景的受版本管理测试套件，视觉/交互仍需单独验收 |
| 当前成熟度与未来需求 | 原型闭环部件可继续迭代；基地、跨战斗成长、设施/任务与 checkpoint 缺口明确，不等于试玩版完成 |

优先级按内容任务决定：批量新机制卡前先处理资源语义/效果载荷与 Buff 设计；远征成长前先处理跨战斗数据契约。旧效果与失效场景的清理可后置；存档保持暂停。未决项保留：Buff 归属/消耗时机、类型默认资源、同阵营精确并列排序、CardInstance.modifiers 转换及高级伤害/Shield 规则（见 GAME_DESIGN §31、34、42–43、63–69）。实例身份传递已按本次明确任务实现，不据此确定其他转换规则。

## 12. 本次验证记录

日期：2026-10-28；只修改 ARCHITECTURE 与 CODEMAP。以下为本次重新执行的验证；未重跑的旧探针结果不作为本次证据。

- 静态清单：52 个项目 `.gd`、22 个 `.tscn`、12 个 `.tres`（不含 addons/cache）。检查保存层级、脚本挂载、主要导出引用/信号连接代码与内容生产链；扫描场景/资源显式 `res://` 外部引用，仅发现旧 `WorldSystem/DebugFreeCamera.tscn` 的缺失脚本。两个 `.tmp` 单独作为遗留材料查看，不算有效场景。
- CLI：经 `tools/godot_cli.ps1 --version` 确认为 `4.7.2.stable.official.ed1daf0bf`。临时 SceneTree 探针存于仓库外，通过同一 wrapper 的 `--headless --path . --script <absolute_probe.gd>` 执行；52 个脚本加载并通过 `can_instantiate()`，21 个可用场景加载并实例化、12 个资源加载，64 处保存 NodePath 可解析，断言失败 0。旧 DebugFreeCamera 场景显式跳过，未声称全仓场景无错误。场景保存连接数为 0，主要信号由脚本动态连接，不能把此计数解释为无事件通信。
- 有限运行：真实远征场景入树后生成/装配默认地图并进入 EXPLORE；Battle 初始未激活且锁定；provider 和 Battle 必需引用校验通过。直接调用 start_battle 与表现门闩（未经过走门/运镜），以现有 1001 敌人三次空等推进至 T=30，玩家 HP 100→90，后续敌人排期 T=120；随后取消 Timeline 并释放场景。覆盖首轮攻击与一次补排，不覆盖完整胜负。
- 环境输出：存在 `Failed to read the root certificate store`；冷却池为空时出现已有的“下一次从 T=90 规划”恢复警告；应用断言失败 0、最终 probe 与 wrapper 退出码 0。不能据此声称 stderr 全空。首轮探针因提前静态引用业务类型，在 Autoload 注册前编译失败；移除探针里的提前类型引用后复跑，未修改业务源码。
- 进程：最终 Godot 测试 PID `7212`、wrapper PID `36644` 已退出；此前探针 PID `7884/7680` 及其 wrapper 也已退出。进程检查仅留下原有用户 Editor PID `26364`；`netstat` 未见测试后的 9876/9877 TCP 监听，测试运行桥 9877 已释放。未终止用户进程。
- 文档验证：核对真实文件路径、主要方法/信号名、Markdown 内部链接及差异范围，并执行 `git diff --check`；未将静态检查当作完整 Runtime 验证。

未执行：Editor MCP/Runtime MCP 现场检查、窗口渲染/截图/人工交互、完整走门与运镜、胜利清敌/失败重开回归、多 AI/多敌人场景、完整 Buff 组合、不同敌人连续战斗属性残留验证、存档 I/O/恢复、Release/导出包验证。wrapper 隔离自动化 user/temp 数据，探针没有创建、加载或覆盖存档槽。临时探针与日志不加入玩法源码或受版本管理的测试入口。

### 主菜单、卡牌身份与武器元数据补充验证（2026-10-28）

本任务修改 MainMenu、CardInstance、RuntimeCard、BattleManager 并新增 WeaponData / 示例资源，保留任务开始前已暂存的 Base、素材移动和文档改动。以下证据独立于上方导航审计：

- 经 `tools/godot_cli.ps1` 运行临时 SceneTree 探针，headless 和窗口运行均获得应用断言失败 0、最终标记和退出码 0。窗口最终使用项目原有 Vulkan / Forward+，另做过 Compatibility 检查；未修改 renderer 配置。
- 同模板 4096 个实例 UID 均为 64 位十六进制且无重复；现有旧格式 UID、CardInstance / RuntimeCard JSON 往返、缺失/空/空白/null/非字符串 UID 的替代、修改器字典深拷贝、两参数 RuntimeCard 和旧字典兼容通过。Runtime 基础消耗、时间、优先级、伤害行动及现有 Buff 运算保持测试值。
- 实际 Expedition 场景入树、地图装配进入 EXPLORE，provider 配置通过。直接调用 Battle.start_battle，15 张牌的来源 UID 全部与输入匹配，6 张起手牌与首轮敌人排期完成；不等于完整走门、运镜或完整遭遇回归。
- 按 project.godot 原主场景引用加载菜单，两个按钮名称/中文标签与单次保存连接通过；1920×1080、1280×720、640×360 下按钮矩形均位于菜单内。最终窗口探针注入鼠标按下/释放，进入精确 `res://BaseSystem/Base.tscn` 并确认 Field；重新加载菜单后聚焦 Quit 并注入 Enter，正常退出。1280×720 截图已检查中文字体与居中布局。场景加载失败分支仅源码检查，未破坏真实 Base 资源来注入失败。
- 示例资源加载为 `WeaponData`，ID 1、名称、描述有效。无 registry，因此没有 ID 查询/重复 ID 行为；此任务不定义武器牌组格式或全局访问。
- stderr 仍有 `Failed to read the root certificate store`，旧数据替代 UID 的警告是预期输出；不声称日志全空。首轮探针的 JSON 数字类型比较和错误敌人测试 ID，以及后续鼠标注入坐标空间问题均已在临时探针中修正；最终应用断言失败 0。
- 最终窗口 Godot PID `41756`、wrapper PID `31660` 已退出；此前任务启动的验证进程亦已退出。9876/9877 无 TCP 监听，用户 Editor PID `21680` 保留。未操作用户存档，临时探针运行后移除；日志和截图留在忽略的 `.codex_runtime/task_menu_identity/`。

未验收：完整战斗胜负、跨战斗状态、Base 内交互与可见场景内容、Base-to-Expedition、存档恢复、导出包。CardInstance.modifiers 的 runtime 语义及 Weapon = Deck 的具体字段仍待设计。

### 主菜单、卡牌身份与武器元数据补充验证（2026-10-28）

本任务修改 MainMenu、CardInstance、RuntimeCard、BattleManager 并新增 WeaponData / 示例资源，保留任务开始前已暂存的 Base、素材移动和文档改动。以下证据独立于上方导航审计：

- 经 `tools/godot_cli.ps1` 运行临时 SceneTree 探针，headless 和窗口运行均获得应用断言失败 0、最终标记和退出码 0。窗口最终使用项目原有 Vulkan / Forward+，另做过 Compatibility 检查；未修改 renderer 配置。
- 同模板 4096 个实例 UID 均为 64 位十六进制且无重复；现有旧格式 UID、CardInstance / RuntimeCard JSON 往返、缺失/空/空白/null/非字符串 UID 的替代、修改器字典深拷贝、两参数 RuntimeCard 和旧字典兼容通过。Runtime 基础消耗、时间、优先级、伤害行动及现有 Buff 运算保持测试值。
- 实际 Expedition 场景入树、地图装配进入 EXPLORE，provider 配置通过。直接调用 Battle.start_battle，15 张牌的来源 UID 全部与输入匹配，6 张起手牌与首轮敌人排期完成；不等于完整走门、运镜或完整遭遇回归。
- 按 project.godot 原主场景引用加载菜单，两个按钮名称/中文标签与单次保存连接通过；1920×1080、1280×720、640×360 下按钮矩形均位于菜单内。最终窗口探针注入鼠标按下/释放，进入精确 `res://BaseSystem/Base.tscn` 并确认 Field；重新加载菜单后聚焦 Quit 并注入 Enter，正常退出。1280×720 截图已检查中文字体与居中布局。场景加载失败分支仅源码检查，未破坏真实 Base 资源来注入失败。
- 示例资源加载为 `WeaponData`，ID 1、名称、描述有效。无 registry，因此没有 ID 查询/重复 ID 行为；此任务不定义武器牌组格式或全局访问。
- stderr 仍有 `Failed to read the root certificate store`，旧数据替代 UID 的警告是预期输出；不声称日志全空。首轮探针的 JSON 数字类型比较和错误敌人测试 ID，以及后续鼠标注入坐标空间问题均已在临时探针中修正；最终应用断言失败 0。
- 最终窗口 Godot PID `41756`、wrapper PID `31660` 已退出；此前任务启动的验证进程亦已退出。9876/9877 无 TCP 监听，用户 Editor PID `21680` 保留。未操作用户存档，临时探针运行后移除；日志和截图留在忽略的 `.codex_runtime/task_menu_identity/`。

未验收：完整战斗胜负、跨战斗状态、Base 内交互与可见场景内容、Base-to-Expedition、存档恢复、导出包。CardInstance.modifiers 的 runtime 语义及 Weapon = Deck 的具体字段仍待设计。
