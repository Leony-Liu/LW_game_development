# ARCHITECTURE

## 0. 文档作用与阅读方式

本文是项目的**人类可读实现架构指南**。它回答“某个功能由哪些系统共同实现、重要状态由谁持有、数据怎样流动、人工修改前应该先理解什么”。

文档边界：

- `Docs/GAME_DESIGN.md` 说明游戏**应该怎样玩**，是玩法与体验规则的权威来源。
- `Docs/CODEMAP.md` 提供面向 Codex 的精确文件导航；本文不会复制完整脚本索引。
- `Docs/README.md` 提供项目概览、当前阶段、阻塞和近期验证状态。
- 本文说明系统职责、状态归属、关键 SceneTree、跨系统流程和当前实现与目标架构的边界。

涉及当前实现时，以真实 `project.godot`、`.tscn`、`.gd`、`.tres` 及明确记录的 Editor / Runtime 观察为准。玩法与代码不一致时，应记录为 implementation gap，而不是用当前代码改写已经确认的设计。

### 证据标签

| 标签 | 含义 |
| --- | --- |
| `[LIVE]` | 已直接核对当前保存配置、场景接线、Editor 状态、定向探针或 Runtime 观察 |
| `[SOURCE]` | 当前源码或保存文件支持该结论，但未声称完整 gameplay 行为已在运行时验证 |
| `[TARGET]` | 已确认的目标架构；不表示已经实现 |
| `[LEGACY]` | 仍存在的旧路径，不应指导新的架构实现 |
| `[VERIFY]` | 当前证据不足；不得猜测 |
| `[PLACEHOLDER]` | 当前文件或节点真实存在，但尚未实现预期职责 |

图中实线表示 SceneTree / 组合关系，带文字的箭头表示调用、signal 或数据流。`Resource` 与 `RefCounted` 只作为数据出现，不是 SceneTree 子节点。

# Part I — 项目整体结构

## 1. 顶层架构总览

本节是概念架构地图，用于表达顶层职责与组合关系；它不默认等同于字面 SceneTree 父子关系。只有明确标为当前保存结构或 `[LIVE]` 的内容，才表示已核对真实场景装配。

```text
Application
├─ MainMenu                         [LIVE]
├─ GameManager                      [PLACEHOLDER] / application flow [TARGET]
├─ SaveManager                      [LIVE]
├─ PlayerSaveManager                [PLACEHOLDER] / persistent player owner [TARGET]
├─ AllCardData                      [LIVE]
└─ AllEnemyData                     [LIVE]

ExpeditionSystem                    [LIVE]
├─ ExpeditionManager                [LIVE] World↔Battle coordinator
├─ PrototypePlayerDataProvider      [LIVE, temporary]
├─ WorldSystem
├─ BattleSystem                     [resident]
└─ UISystem
```

`project.godot` 当前把 `MainMenuSystem/MainMenu.tscn` 设为主场景，并注册 `GameManager`、`SaveManager`、`AllCardData`、`AllEnemyData` 为 gameplay Autoload。`godot_mcp_runtime` 也是 Autoload，但属于开发基础设施，不属于 gameplay ownership。`[LIVE]`

当前 Application 层尚未把主菜单、Base 与 `ExpeditionSystem` 串成正式流程；远征内部的 World、Battle 与临时输入节点已经在同一保存场景中装配。`[LIVE][TARGET]`

## 2. 核心系统职责

以下表是本文对主要职责的唯一权威摘要；后续章节只在具体流程中补充上下文。

| System | 主要负责 | 不应该负责 | 当前状态 |
| --- | --- | --- | --- |
| `GameManager` | Application 级 Base / MainMenu ↔ Expedition 流程 | 战斗细节、地图事实、存档文件格式 | `[PLACEHOLDER]`；目标职责为 `[TARGET]` |
| `ExpeditionManager` | 一次远征内 World ↔ Battle 的唯一上层协调；组合战斗输入、协调表现就绪、保存交接上下文、消费战斗结果 | 复制 `WorldManager` 地图真相；接管单场战斗内部状态 | encounter、startup 与进入 Battle 的表现门闩已实现 `[LIVE]`；result handoff 未实现 `[TARGET]` |
| `PrototypePlayerDataProvider` | 从 Inspector 临时生成 `EntityData` 与 `CardInstance[]` | 长期玩家数据、敌人选择、战斗生命周期、持久化 | `[LIVE]` 临时原型输入；构造与错误路径已定向验证 |
| `WorldManager` | 当前 `mapdata`、当前房间坐标、World mode、遇敌事实 | 长期玩家数据；单场 Battle lifecycle | `[SOURCE]` |
| `WorldGenerator` | 由 `MapBlueprint` 生成 rooms / doors 数据 | 持有运行时地图；创建战斗 | `[SOURCE]` |
| `RoomSet` / `BattleRoom` / `DoorSet` | 根据 `mapdata` 创建房间与门的场景实例；以原 `RoomData` 定位房间实例和敌人接近锚点；中继门事件 | 成为地图数据权威 | `[LIVE][SOURCE]` |
| `PlayerVisualManager` | 探索 / 准备 / 战斗 / 调试模式下的控制、相机与鼠标组合；协调真实玩家的遇敌接近运镜 | 持有房间、遭遇或战斗真相 | `[LIVE]` |
| `BattleManager` | 一场战斗的启动、子系统协调、内部输入锁、Battle UI 门闩、表现等待和结束信号 | 地图状态、长期成长、远征持久化真相 | `[LIVE]` |
| `Timeline` | 逻辑时间、行动队列、排序与推进 | 伤害结算；EnemyAI 决策 | `[SOURCE]` |
| `EnemyAI` | 根据 `EnemyAction` 池规划敌人行动与 cooldown 状态 | Timeline 排期规则；实体数值结算 | 首次规划存在；持续闭环不完整 `[SOURCE]` |
| `EntityManager` | 初始化战斗实体；把 `CombatAction` 路由到实体 / 卡牌边界；资源查询与扣除 | Timeline 排期；长期实体存档 | `[SOURCE]` |
| `CombatEntity` / `AttributeSet` | 战斗实体及其实际属性集合；接收属性冲击和实体 Buff | 行动选择、地图状态、牌堆 | `[SOURCE]` |
| `CardManager` | `draw_pile` / `hand_pile` / `discard_pile` 和卡牌流转 | 卡牌 UI 节点作为逻辑真相；战斗外卡牌持久化 | `[SOURCE]` |
| `RuntimeCard` | 单场战斗内一张牌的可变状态、Buff 后数值和 `CombatAction` 构造 | 长期卡牌 identity / progression 的权威来源 | `[SOURCE]` |
| `SaveManager` | slot、metadata、module registry、JSON file I/O | 任何 gameplay-specific 状态 | `[SOURCE]` |
| `PlayerSaveManager` | 长期玩家数据与成长的权威 owner | 通用文件 I/O；World / Battle 临时状态 | `[PLACEHOLDER]`；目标职责为 `[TARGET]` |
| `AllCardData` / `AllEnemyData` | 从资源目录加载静态模板并按 ID 提供查询 | 拥有可变卡牌、实体或战斗状态 | `[SOURCE]` |

## 3. 核心状态归属

### 当前存在的权威状态

| 状态 | 当前 owner | 说明 |
| --- | --- | --- |
| 当前地图 `mapdata` | `WorldManager` | `rooms` 与 `doors` 的运行时容器；房间内保存 `RoomData` |
| 当前房间 | `WorldManager.current_room_coords` | 目前在门事件中推导并更新 |
| World mode | `WorldManager.current_state` | `INIT / EXPLORE / PREPARING_BATTLE / BATTLE` |
| 单场 Battle 是否激活 | `BattleManager.is_battle_active` | 只属于当前战斗生命周期 |
| Battle 表现是否就绪 | `ExpeditionManager` 根据 `WorldManager.world_state_changed` 协调 | 只在 World 进入 `BATTLE` 后开放 UI；不覆盖 Battle 内部锁 |
| Battle 内部输入限制 | `BattleManager` | Timeline 推进等单场战斗约束；与表现门闩合并为最终输入锁 |
| 逻辑时间与行动队列 | `Timeline.current_time` / `action_line` | Timeline 是唯一调度 owner |
| 抽牌 / 手牌 / 弃牌 | `CardManager` | UI 仅显示并提交请求 |
| 战斗属性值 | 每个 `CombatEntity` 下的 `AttributeSet` / `Attribute` | `EntityData` / `EnemyData` 是初始化输入，不是已实例化后的数值 owner |
| 单卡 Battle Buff | `RuntimeCard.active_buffs` | 只属于当前战斗内的卡牌实例 |
| slot / metadata / module registry | `SaveManager` | 通用存档基础设施 |

### 已确认但尚未实现的归属

| 状态 | 目标 owner | 状态 |
| --- | --- | --- |
| Base ↔ Expedition 应用流程 | `GameManager` | `[TARGET]` |
| 一次探索 ↔ 战斗交接上下文 | `ExpeditionManager` | `[TARGET]` |
| 长期玩家 / 武器 / 牌组 / 成长数据 | `PlayerSaveManager` | `[TARGET]` |
| Room Entry / Battle Start checkpoint | 一个 expedition-level persistence boundary | `[TARGET]`；具体类型与路径未实现 |

目标 owner 应协调现有 owner，而不是复制它们的可变状态。特别是，不应为方便再创建第二个全局地图、牌堆、战斗或玩家数据真相。

# Part II — 功能是如何实现的

## 4. 应用入口与 Base / Expedition 边界

当前入口是 `MainMenuSystem/MainMenu.tscn`，场景只有一个无脚本的 `MainMenu` 根节点。`GameManager` 已作为 Autoload 存在，但脚本只有空的 `_ready()` / `_process()`；工程中也没有已实现的 Base 场景入口或 `GameManager → ExpeditionSystem` 切换。`[LIVE]`

目标边界：`GameManager` 只管理 Application 级流程，例如 Base / MainMenu 与 Expedition 的进入、退出和高层场景切换；进入远征后，探索 ↔ 战斗由 `ExpeditionManager` 接管。`[TARGET]`

因此，人工修改应用入口时应先区分：

- “从菜单/基地开始或结束一次远征”属于 `GameManager`；
- “同一次远征里遇敌、开战、返回原房间”属于 `ExpeditionManager`；
- 单场战斗内部流程属于 `BattleManager`。

## 5. Expedition 顶层组织

`ExpeditionSystem/ExpeditionSystem.tscn` 当前保存结构：

```text
Expedition‌System
├─ ExpeditionManager
├─ PrototypePlayerDataProvider
├─ WorldSystem
│  ├─ RoomSet
│  ├─ DoorSet
│  ├─ PlayerVisualRoot/PlayerVisual
│  └─ WorldGenerator
├─ BattleSystem
└─ UISystem
```

`ExpeditionManager.world_manager`、`battle_manager`、`prototype_player_data_provider` 已分别绑定三个 sibling，并在 `_ready()` 中强校验。`BattleSystem` 是 `ExpeditionSystem` 的常驻实例，而不是每次遇敌时临时创建。`[LIVE]`

常驻 `BattleSystem` 的架构意义是：远征协调器可以持有稳定引用，World / Battle 的交接无需通过临时实例化来表达；每场战斗的开始与结束应由明确的 lifecycle reset 完成。常驻并不代表跨战斗临时状态已经正确清理；第二场战斗的 queue、Buff、visual wait、input lock 等仍需后续运行验证。`[TARGET][VERIFY]`

`PrototypePlayerDataProvider` 通过显式配置标志与 Inspector 字段生成 `EntityData` 和 `CardInstance[]`。默认未配置时不会伪造数据；无效 Card ID 会使整组牌失败，不返回部分牌组。它只是正式玩家数据链完成前的远征内输入适配器。`[LIVE]`

## 6. 地图生成与 WorldSystem

地图链如下：

```text
MapBlueprint
→ WorldManager.init_map()
→ WorldGenerator.generate()
→ mapdata { rooms, doors }
→ WorldManager 持有
├─ RoomSet.build_rooms()
└─ DoorSet.build_doors()
```

`MapBlueprint` 是静态生成配置；`WorldGenerator` 创建 `RoomData`、房间连接与门坐标，并通过 `AllEnemyData` 按 enemy level 选择敌人 ID。它返回数据后不继续拥有地图。`[SOURCE]`

`WorldManager` 把返回的 `mapdata` 作为当前运行时地图真相，设置 `current_room_coords`，再让 `RoomSet` / `DoorSet` 创建表现节点。`RoomSet` 动态实例化 `BattleRoom.tscn`；`DoorSet` 动态实例化 `Door.tscn`。`[SOURCE]`

地图规模、概率和权重属于 `MapBlueprint` / `GAME_DESIGN` 的配置与调参范围，不应写进系统 ownership。人工修改生成算法时，应优先理解 `MapBlueprint → WorldGenerator → mapdata`；修改房间外观不应把生成职责搬进 `BattleRoom`。

## 7. 房间、门与探索表现

### 房间数据与表现

`RoomData` 是地图内单个房间的数据对象，包含坐标、类型、敌人标记 / ID、进入方向和连接方向等。`BattleRoom` 引用一份 `RoomData`，据此搭建墙、门洞、地面、天花板和敌人表现；`clear_enemies()` 会修改这份房间数据并发出 `room_data_changed`。`[SOURCE]`

`RoomSet` 负责“根据整张地图创建哪些房间节点”；`BattleRoom` 负责“一个房间节点怎样反映其 `RoomData`”。二者都不应成为独立地图真相。

### 门与房间转换

```text
Door.open_door()
→ door_opened(door)
→ DoorSet.door_opened_relay(door)
→ WorldManager._on_door_opened()
→ 推导门后房间坐标与 RoomData
```

当前 `WorldManager` 根据 player / door 世界坐标、门后偏移与 10-unit 网格推导目标房间，并直接更新 `current_room_coords`。`[SOURCE]`

`Door._process()` 的当前分支在门开启且动画结束后，无论玩家仍在检测范围内还是已离开都会调用 `close_door()`；实际手感与时序仍需定向运行验证。`[SOURCE][VERIFY]`

### 移动与相机

`PlayerVisualManager` 组合 `PlayerController`、`HeadController`、`CameraBobMount`、`PlayerCamera` 与场景内 `DebugFreeCamera`，负责 explore / preparing_battle / battle / debug 模式下的输入与相机启停。准备期由 `PlayerController` 使用原 `CharacterBody3D` 和 `move_and_slide()` 接近目标，`HeadController` 平滑完成垂直朝向；移动状态继续驱动镜头 bob。`[LIVE][SOURCE]`

人工修改时：房间内容看 `RoomData` / `BattleRoom`；门交互看 `Door` / `DoorSet` / `WorldManager`；探索移动与相机看 `PlayerVisual.tscn` 及其 `PlayerVisual/Scripts/` 组件；房间切换规则看 `WorldManager`。

## 8. Exploration ↔ Battle

这是远征纵向闭环的关键边界。

### 目标流程 `[TARGET]`

```text
WorldManager
→ encounter fact（概念；尚无正式类型）
→ ExpeditionManager
→ 组合 EntityData + CardInstance[] + enemy_id
→ BattleManager.start_battle() -> bool

BattleManager
→ battle result（概念；当前只有 bool signal）
→ ExpeditionManager
→ 更新 WorldManager / 原 RoomData
→ 恢复同一次 expedition、同一 mapdata、同一 room context
```

`EncounterFact` 仍只是目标概念，不存在同名类；M1-02 已用 typed signal 落地最小 `RoomData + enemy_id` contract。`BattleResult` 仍是目标概念，正式类型、字段和 API 尚未定义。`[LIVE][TARGET][VERIFY]`

### 当前真实流程 `[LIVE]`

```text
Door opened
→ DoorSet relay
→ WorldManager 查找 target RoomData
→ current_room_coords = target room
→ target_room.has_enemies ?
→ WorldManager.report_encounter(RoomData)
→ 校验 RoomData / enemy_id，并设置请求门闩
→ encounter_requested(RoomData, enemy_id)
→ ExpeditionManager._on_world_encounter_requested()
→ 校验当前房间、provider、Battle 状态与输入引用
→ BattleManager.start_battle(CardInstance[], EntityData, enemy_id) -> bool
→ 成功：resolve_encounter_request(..., true) → PREPARING_BATTLE
→ RoomData → RoomSet → BattleRoom.EnemyRoot/EncounterApproachAnchor
→ PlayerVisualManager 启动带 transition id 的第一人称自动接近
→ 距离、身体 / 镜头朝向和 settle 均完成 → WorldManager.BATTLE
→ world_state_changed → ExpeditionManager → BattleManager.set_presentation_ready(true)
→ 失败：resolve_encounter_request(..., false) → 保持 EXPLORE，可重试
```

当前 encounter contract 是 `WorldManager.encounter_requested(room_data: RoomData, enemy_id: int)`。`RoomData` 仍是 World 持有的原对象，`enemy_id` 是交接所需的明确事实，不复制地图状态。`WorldManager` 在请求完成前拒绝重复 / 重入上报；空房间、无敌房间、无效或不存在的敌人 ID 会明确失败。`report_encounter()` 返回同步协调后的最终接受结果，而不是仅表示 signal 已发出；匹配请求无论接受或拒绝都会释放 pending。`[LIVE]`

`ExpeditionManager` 已连接该 signal，并使用 `PrototypePlayerDataProvider` 的公开 API 组装 `EntityData` 与 `CardInstance[]`。它要求传入房间仍是 `WorldManager` 当前唯一 pending encounter，并在输入构造前后校验上下文；敌人接近锚点、玩家实体或第一人称相机无效时也不会启动 Battle。无效 provider、重入请求、陈旧房间、缺失 pending 或已激活 Battle 都不会调用正常启动。失败请求同步释放，可恢复配置修正后允许重试。`[LIVE]`

`BattleManager.start_battle(...) -> bool` 具有独立启动门闩。它先调用 `EntityManager.can_initialize()` 与 `CardManager.can_initialize()` 完成无副作用预检，再写入实体、EnemyAI / Timeline 与牌堆状态；只有两个 initialize 都明确成功后才设置 `is_battle_active`、发出一次 `battle_started` 并返回 `true`。已知可恢复错误因此不会留下部分实体、行动队列、牌堆或卡牌 UI。失败状态会保持 Battle 未激活、表现关闭、输入锁定。`[LIVE]`

进入 `PREPARING_BATTLE` 后，`PlayerVisualManager` 停用探索移动与视角输入、保留玩家相机并释放鼠标；Battle UI 与卡牌输入保持关闭。`RoomSet` 以原 `RoomData` 身份取得对应 `BattleRoom` 的 `EnemyRoot/EncounterApproachAnchor`，真实玩家实体沿碰撞几何接近目标并平滑面向敌人。完成回调携带 transition id，`WorldManager` 还会复核原 `RoomData`、当前房间和目标节点身份；只有实际到达、朝向和 settle 完成后才进入 `BATTLE` 并开放 Battle 表现门闩。`[LIVE]`

运镜具有最长运行时间并显式处理目标释放。由于当前没有 Battle 激活后的 rollback contract，运行中目标失效或移动超时时不会伪造运镜成功，而是记录错误并降级进入已经初始化的 `BATTLE`，以保持 World / Battle 表现一致并避免玩家永久锁定；若房间身份也已失效，则拒绝推进，等待后续正式 cleanup contract 处理。`[LIVE][TARGET]`

Battle 最终输入锁由 `BattleManager` 合并两个来源：远征层的 presentation readiness，以及 Battle 内部的 Timeline / lifecycle lock。前者不能解开后者；卡牌会持久保存 system lock，抽牌或拒绝动画结束不会自行恢复交互。`BattleManager` 通过 InputMap 动作 `combat_draw_to_full` / `combat_advance_time` 接收补牌与空等输入，并在同一合并锁后分别调用 `CardManager.execute_player_draw_action()` 与 `Timeline.advance_timeline_to()`；物理按键不写入 gameplay 逻辑。`[LIVE]`

当前没有 Battle 激活后的取消 / rollback contract。运镜自身失败且原房间仍有效时会显式降级进入已初始化的 Battle；若准备阶段被外部强制改成错误房间或其他不一致状态，则不能安全返回探索或自动重试。该缺口仍需后续明确的 Battle cleanup / result lifecycle 解决，不能在启动失败处理中伪造战斗结果或清除房间。`[TARGET][VERIFY]`

战斗结束时，`BattleManager` 发出 `battle_ended(is_player_victory: bool)`；仓库中没有 receiver。`WorldManager.finish_battle()` 也没有连接，它只把当前 `RoomData.has_enemies` 设为 `false`，未清空 `enemy_id`，然后回到 explore。`[SOURCE]`

实现此闭环时，`ExpeditionManager` 应保存 exactly-once 的 encounter context 并协调两边；不应让 `WorldManager` 拼装长期玩家数据，也不应让 `BattleManager` 直接修改地图。

## 9. BattleSystem

当前保存场景：

```text
BattleSystem [BattleManager]
├─ Timeline
├─ EnemyAI
├─ EntityManager
│  ├─ PlayerEntity
│  │  └─ AttributeSet
│  └─ EnemyEntity
│     └─ AttributeSet
└─ UI
   ├─ CardSystem [CardManager]
   └─ PlayerInformation
```

`BattleManager.timeline`、`entity_manager`、`card_manager`、`battle_ui`，以及 `EntityManager.player_entity`、`enemy_entity`、`enemy_ai` 均已保存绑定并有启动期强校验。旧 `CombatManager` 节点与缺失脚本引用已经移除。`battle_save_module` 为 `null`。`[LIVE]`

当前启动入口是：

```gdscript
start_battle(
    external_deck: Array[CardInstance],
    external_player_data: EntityData,
    enemy_id: int
) -> bool
```

启动时，`BattleManager` 先校验引用与输入，把 `CardInstance[]` 转成 `RuntimeCard[]`，再对 Entity / Enemy resource / Enemy action pool 与 Card / hand deck / card scene 做无副作用预检。预检全部通过后才依次初始化 Entity 与 Card；全部成功后进入 active、发出 `battle_started` 并返回 `true`。此时 UI 和卡牌输入仍由 presentation gate 关闭，直到 World 正式进入 `BATTLE`。已激活 Battle、重入启动、无效输入或子系统预检失败返回 `false`。`[LIVE]`

战斗中的主要协调链：

```text
Card UI request
→ CardManager
→ BattleManager（仲裁资源、锁输入）
→ Timeline
→ BattleManager（接收到期 CombatAction）
→ EntityManager / CardManager
→ CombatEntity / Attribute / RuntimeCard
→ visual request（如有）
→ BattleManager 等待 presentation completion
→ Timeline 继续推进
```

当前代码中 `RuntimeCard` 会按 card type 选择 stamina / mana cost 字段，但 `BattleManager` 始终用 `"stamina"` 检查和扣费。这是当前跨边界实现不一致，不是最终玩法规则；资源映射由 `GAME_DESIGN` 中的待设计项决定。`[SOURCE]`

## 10. 卡牌从数据到行动

```text
CardData
→ AllCardData 按 ID 查询
→ CardInstance
→ BattleManager.start_battle()
→ RuntimeCard
→ CardManager 牌堆 / 手牌
→ Timeline.receive_card(RuntimeCard)
→ RuntimeCard.create_action()
→ CombatAction
```

四层含义：

- `CardData`：可复用的静态 `Resource` 模板。
- `CardInstance`：战斗前的一张具体卡，可承载 `unique_id` 与长期 / 远征级 `modifiers`。
- `RuntimeCard`：单场战斗内的可变卡牌状态，拥有 `active_buffs` 并计算 cost / time / priority / damage / shield。
- `CombatAction`：已经可进入统一行动流的执行 payload，包含 timing、source / target、属性冲击、实体 Buff 与 Card Buff。

准确的当前调用关系是：`Timeline.receive_card()` 调用 `runtime_card.create_action(...)`；`CombatAction` 由 `RuntimeCard` 构造，**不是 Timeline 自己构造**。Timeline 随后只修正 instant 分支的 `trigger_time`、入队并推进逻辑时间。`[SOURCE]`

`BattleManager._convert_deck_to_runtime()` 当前只传递 `card_id` 与 `card_data`；`CardInstance.modifiers` / `unique_id` 没有进入 `RuntimeCard`。如何转换这些状态仍由 `GAME_DESIGN` 标为待设计，不能在架构文档中替用户决定。`[SOURCE][VERIFY]`

`CardData.play() → CardEffect.execute()` 的旧路径仍存在，与 `RuntimeCard → CombatAction` 主链并存；新效果不应同时扩展两套协议。`[LEGACY]`

## 11. Timeline 与统一行动流

```text
RuntimeCard / EnemyAI
→ CombatAction
→ Timeline
→ BattleManager
→ EntityManager
→ CombatEntity / CardManager
```

`Timeline` 拥有 `current_time`、`action_line`、`is_advancing`，按 `trigger_time`、Priority-0 最先 / 其余 priority 升序、玩家优先 tie-break 排序。它在发出 `action_triggered(action)` 前登记当前待完成行动；`BattleManager` 完成 gameplay 与可选表现后以同一个 `action` 调用 `notify_action_finished(action)`。同步确认会在 signal 返回后被直接观察到，异步确认会唤醒等待；重复或过期行动引用不能完成其他行动。Battle 结束时 `cancel_advancement()` 会清空队列并解除当前等待。`[LIVE][SOURCE]`

职责边界：

- Timeline 负责“何时执行、先后顺序、推进多少逻辑时间”。
- `RuntimeCard` / `EnemyAI` 负责把各自意图变成 `CombatAction`。
- `BattleManager` 负责协调结算、输入锁和表现等待；当前未接战斗表现控制器时，视觉请求立即视为完成，未来控制器通过 `notify_visual_completed()` 接回同一确认边界。
- `EntityManager` / `CombatEntity` 负责把行动应用到实际战斗状态。
- Timeline 不拥有伤害真相，也不决定敌人下一步做什么。

具体时间消耗、instant 语义和 tie-break 是否为最终规则由 `GAME_DESIGN` 决定；本文只描述当前实现边界。

## 12. Entity / Attribute

```text
EntityData（player start input） / EnemyData（static resource）
→ EntityManager.initialize()
→ CombatEntity
→ AttributeSet
→ Attribute
→ optional AttributeBuff
```

玩家侧由 `EntityData.export_to_attribute_map()` 生成初始属性；敌人侧由 `AllEnemyData` 返回 `EnemyData`，`EntityManager` 注册其 `attributes`。初始化完成后，实际战斗值位于各 `CombatEntity.attribute_set` 管理的 `Attribute` 对象中。`[SOURCE]`

`CombatAction.attribute_impacts` 由 `EntityManager` 路由给目标 `CombatEntity`。当前 `CombatEntity` 对负向 `hp` 先消耗 shield，再扣 hp；其他属性直接进入对应 `Attribute`。`Attribute` 保存基础计算值、可选 custom formula 和 `AttributeBuff[]`，并在值变化时逐层上报 UI / death 事件。`[SOURCE]`

`AttributeBuff` 是运行时轻量数据，不是静态数据库，也不是持久化 owner。最终伤害、防御、shield 生命周期等玩法语义仍以 `GAME_DESIGN` 为准。

## 13. EnemyAI

敌人行动链：

```text
EnemyData.action_pool: Array[EnemyAction]
→ EntityManager.initialize()
→ EnemyAI.setup_ai()
→ EnemyAI.plan_initial_actions()
→ CombatAction
→ EntityManager signal relay
→ BattleManager
→ Timeline.add_action()
```

`EnemyAI` 持有行动池、加权选择、cooldown tracker 与 `_last_planned_time`，因此 AI planning / decision state 属于 EnemyAI；Timeline 只持有已生成行动的时间与队列。`[SOURCE]`

当前首次 planning 路径、`enemy_ai` 场景引用及首场 `start_battle()` 初始化已经定向运行验证。行动完成后，仍没有代码再次调用 `plan_next_action(current_timeline_time)`；所有行动冷却时把 planning pointer 向后推 10 但没有自动重试闭环。`[LIVE][SOURCE][VERIFY]`

试玩版设计已要求敌人形成持续行动闭环，但由谁触发下一次 planning 仍是架构实现问题。本文不替该缺口设计新 signal 或 owner；未来实现必须保留“EnemyAI 决策、Timeline 排期”的边界。

## 14. Card Buff / effect application boundary

当前一个 `CombatAction.card_buffs` 有两条应用路径：

```text
Path A
BattleManager receives action
→ EntityManager.execute_action()
→ card_buff_requested
→ BattleManager
→ CardManager

Path B
BattleManager receives action
→ directly loops action.card_buffs
→ CardManager
```

同一个 Buff 因此可能被应用两次。`[SOURCE]`

这是 authority conflict：`EntityManager` 的 signal 路由与 `BattleManager` 的直接路由同时声称拥有 CardBuff application boundary。目标架构必须只保留一条权威路径。最终 Buff 语义、目标范围与消耗时机仍由 `GAME_DESIGN` 决定；本文不选择具体修法。`[TARGET][VERIFY]`

# Part III — 存档与长期状态

## 15. SaveManager 与长期玩家状态

`SaveManager` 是通用基础设施 Autoload：

```text
SaveModule implementations
→ register_module()
→ SaveManager
→ metadata + modules_data
→ user://saves/<slot_id>.json
```

它拥有 slot、metadata、module registry、文件读取 / 写入与 module lifecycle，不拥有玩家、地图或战斗业务状态。注册模块通过 `get_save_data()` / `load_save_data()` / `clear_data()` 提供自己的数据。`[SOURCE]`

`PlayerSaveManager.gd` 当前存在但未挂载、未注册、没有实际数据或接口。它的目标职责是长期玩家、武器 / 牌组、装备与成长数据的权威 owner；通用文件 I/O 仍属于 `SaveManager`。`[PLACEHOLDER][TARGET]`

## 16. Expedition Checkpoint Architecture

试玩版保存粒度已经由 `GAME_DESIGN` 确定，不再把“精确 Battle mid-state restore”当作未决问题。

### Room Entry Checkpoint `[TARGET]`

当玩家通过门进入新房间时，checkpoint 表示“刚进入当前房间的那一刻”。它需要足以恢复该时刻已提交的远征状态，以及对应 N / E / S / W 进入方向的恢复位置。

当前房间内、尚未通过下一次门转换提交的行为在重载后回滚。具体 gameplay 字段以 `GAME_DESIGN` 为准；架构实现应在进入房间这一边界收集所需数据。

### Battle Start Checkpoint `[TARGET]`

战斗开始时保存能重建整场战斗的输入：

```text
battle-start player data
+ battle-start weapon / CardInstance[]
+ enemy_id
```

若战斗期间中断：

```text
load battle-start checkpoint
→ reconstruct Battle
→ restart the entire Battle
```

试玩版不要求序列化：

- `Timeline.current_time` 或当前 action queue；
- draw / hand / discard 当前顺序；
- `RuntimeCard.active_buffs`；
- 战斗中途 HP；
- EnemyAI 中间 planning / cooldown；
- animation / visual wait / input-lock transient state；
- 其他只属于正在进行 Battle 的临时状态。

因此，`RuntimeCard.to_dictionary()` 当前不保存 `active_buffs` 不是试玩版 checkpoint 的架构阻塞；也不应围绕 legacy `BattleSaveModule.gd` 设计新的 save contract。

## 17. Expedition persistence ownership

目标是一个 expedition-level persistence boundary：

```text
WorldManager / ExpeditionManager / battle-start inputs
→ one expedition snapshot/checkpoint coordinator
→ SaveModule adapter（具体类型未定）
→ SaveManager generic I/O
```

它负责协调 Room Entry 与 Battle Start 两种 checkpoint，而不是让 World save 与 Battle save 各自维护一份持久化真相。`[TARGET]`

这个 boundary 可以读取各系统的权威状态并生成 snapshot，但不应成为第二个运行时 owner。恢复时也应通过 `ExpeditionManager` 重新装配 World / Battle 上下文，而不是让 `BattleManager` 直接恢复地图或让 `WorldManager` 直接恢复 Battle internals。

具体类名、文件路径、schema、module key 和注册时机尚未实现，保持 `[TARGET][VERIFY]`。当前不要求兼容旧存档。

# Part IV — 表现层与静态数据

## 18. Presentation boundary

通用边界：

```text
gameplay state owner
→ signal / event / presentation request
→ presentation
→ optional completion callback
```

表现层可以拥有动画进度、hover、当前展示节点、镜头模式等本地状态，但不能成为 gameplay 真相。

当前例子：

- `PlayerVisualManager` 反映 World mode；不拥有当前房间或遇敌状态。
- `CardManager` 拥有逻辑牌堆；`PlayerHandDeck` / `CardLogic` 创建 UI 节点、提交请求并播放确认 / 拒绝动画。
- `ExpeditionManager` 只协调 Battle UI / input 的 presentation gate；`BattleManager` 仍拥有 Timeline 等内部锁，二者共同决定最终卡牌输入状态。
- `CombatEntity` 发出 visual request，经 `EntityManager` / `BattleManager` 转发；当前 `wait_for_combat_presentation == false`，请求不会阻塞 gameplay。未来接入控制器后可启用等待并由 `notify_visual_completed()` 完成表现，但现实动画时长不改变逻辑 `time_cost`。

等待表现完成是同步机制，不意味着表现层有权修改 HP、牌堆、Timeline 或 battle result。

## 19. Static Resource / runtime state boundary

| 数据 | 类型与角色 | 可变运行时状态在哪里 |
| --- | --- | --- |
| `AllCardData` | Autoload 静态卡牌索引 | 不保存单卡状态；具体卡在 `CardInstance` / `RuntimeCard` |
| `CardData` | `Resource` 卡牌模板 | 战斗 Buff 在 `RuntimeCard`；牌堆归 `CardManager` |
| `AllEnemyData` | Autoload 静态敌人索引 | 不保存当前敌人 HP / AI cooldown |
| `EnemyData` / `EnemyAction` | `Resource` 敌人模板与行动配置 | 属性在 `CombatEntity`；规划状态在 `EnemyAI` |
| `MapBlueprint` | `Resource` 地图生成配置 | 当前地图在 `WorldManager.mapdata` |
| `RoomData` | 运行时生成的 `Resource`，存于 `mapdata` | 是当前房间事实的一部分，由 World 侧拥有；`BattleRoom` 只引用和呈现 |

静态资源应描述可复用模板 / 配置，不应被当作一次运行中的可变实体。反过来，`RuntimeCard`、`Attribute`、Timeline queue、EnemyAI cooldown 等 Battle runtime state 不应回写到共享静态资源。

# Part V — 当前工程与目标架构之间的差距

## 20. Legacy / placeholders / hazards

| Item | 状态 | 架构含义 |
| --- | --- | --- |
| `ExpeditionSystem/BattleSystem/Scripts/BattleSaveModule.gd` | `[LEGACY]` | 未挂载、无可靠注册链、字段 / constructor 与当前 `EntityData` / `EnemyData` 不兼容；不得作为新 checkpoint contract 基础 |
| `Scripts/CardData/CardEffect/` 与 `CardData.play()` | `[LEGACY]` | 与 `RuntimeCard → CombatAction` 并存；未经明确迁移任务不要继续扩展或批量删除 |
| `Scripts/GameManager.gd` | `[PLACEHOLDER]` | Autoload 已存在，Application flow 尚未实现 |
| `Scripts/PlayerSaveManager.gd` | `[PLACEHOLDER]` | 未挂载且没有长期玩家数据实现 |
| `ExpeditionSystem/WorldSystem/DebugFreeCamera.tscn` | `[LEGACY]` hazard | 未被当前 Expedition 场景引用，且指向缺失的旧脚本；使用 `PlayerVisual.tscn` 内的 DebugFreeCamera |
| `ExpeditionSystem/ExpeditionSystem.tscn` root name | `[LIVE]` hazard | 实际为 `Expedition‌System`，中间含 U+200C 零宽非连接符；人工写 NodePath / 名称比较时易误判 |
| `ExpeditionSystem/ExpeditionSystem.tscn4534689310.tmp` | `[LEGACY]` tracked temp | 旧 Editor recovery wiring；不要作为真实场景编辑 |
| `ExpeditionSystem/BattleSystem/CardSystem/CardSystem.tscn58389123.tmp` | `[LEGACY]` tracked temp | 含旧路径；不要作为当前 CardSystem 编辑 |

这些项目用于避免人工误入错误路径，不是 cleanup backlog。本任务不修改或删除它们。

## 21. Current vs Target gaps

| Area | Current | Target |
| --- | --- | --- |
| Application flow | `GameManager` 为空；main scene 未接 Expedition | `GameManager` 管理 Base / MainMenu ↔ Expedition |
| Encounter reporting | `WorldManager` 通过 typed signal 上报 `RoomData + enemy_id`，并用门闩防重入 | 已满足；后续只扩展 transition / result，不复制地图 ownership |
| Battle handoff | `ExpeditionManager` 组合 provider 输入并 exactly-once 调用 `start_battle()`；成功后才接受 encounter | 后续 persistent player owner 替换 prototype provider 时保留同一协调边界 |
| Explore → Battle transition | `WorldManager` 驱动 `EXPLORE → PREPARING_BATTLE → BATTLE`；真实玩家完成第一人称接近后，`ExpeditionManager` 才在最终状态开放 Battle 表现门闩 | 已满足；视觉品质仍需人工验收，后续调整保持身份校验与双锁约束 |
| Startup failure recovery | encounter 最终接受结果、pending 释放、上下文身份校验及 Entity/Card 无副作用预检已实现 | Battle 激活后的中断仍需正式 cleanup / result contract |
| Battle result | `battle_ended(bool)` 无 receiver；`finish_battle()` 未连接 | result → `ExpeditionManager` → same World / RoomData |
| Player persistence | `PlayerSaveManager` 未实现 | 长期玩家数据唯一 owner |
| Expedition persistence | 无 expedition module；legacy Battle module 不可靠 | 一个 expedition-level checkpoint boundary |
| Enemy loop | 只有 initial planning path | 保持 AI / Timeline 边界的持续 planning 协调 |
| CardBuff application | 同一 payload 有两条 application path | 单一权威应用路径 |
| Card lifecycle transfer | `modifiers` / `unique_id` 未进入 RuntimeCard | 待 `GAME_DESIGN` 决定后实现明确转换 |

以上是架构差距，不是任务优先级列表；本文不定义实现优先级或生产排期。

# Part VI — 人工修改指引

## 22. “如果我要改这个功能，应先理解什么？”

| 想修改 | 先理解 | 关键实现位置 |
| --- | --- | --- |
| 探索进入战斗 / 战后返回 | `WorldManager → ExpeditionManager → BattleManager` 的 current / target 边界 | `WorldManager.gd`、`ExpeditionManager.gd`、`BattleManager.gd`、`ExpeditionSystem.tscn` |
| 地图生成 | `MapBlueprint → WorldGenerator → WorldManager.mapdata` | `MapBlueprint.gd`、`WorldGenerator.gd`、`WorldManager.gd` |
| 房间 / 门 / 探索移动 | `RoomData` 与 presentation 分离；Door signal relay；PlayerVisual composition | `RoomData.gd`、`BattleRoom.gd`、`RoomSet.gd`、`Door*.gd`、`PlayerVisual.tscn` |
| 卡牌进入战斗 | `CardData → CardInstance → RuntimeCard → CombatAction` | `R_carddata.gd`、`CardInstance.gd`、`RuntimeCard.gd`、`BattleManager.gd` |
| Timeline / 行动结算 | producer 生成 `CombatAction`，Timeline 排期，Entity 层执行 | `Timeline.gd`、`CombatAction.gd`、`BattleManager.gd`、`EntityManager.gd` |
| 敌人行动 | `EnemyData / EnemyAction → EnemyAI → Timeline` | `R_EnemyData.gd`、`R_EnemyAction.gd`、`EnemyAI.gd` |
| 战斗属性 | `EntityManager → CombatEntity → AttributeSet → Attribute` | `EntityData.gd`、`EntityManager.gd`、`CombatEntity.gd`、`Attribute*.gd` |
| 存档 / checkpoint | gameplay owner 与 generic I/O 分离；Room Entry / Battle Start 两个边界 | `SaveManager.gd`、`SaveModule.gd`、`GAME_DESIGN.md` 存档章节；expedition module 尚未实现 |

本表只帮助人先找到正确子系统；更完整、精确的 task → file 导航仍以 `Docs/CODEMAP.md` 为准。

# Part VII — Maintenance

## 23. Architecture invariants

- `GameManager` 负责 Application flow；`ExpeditionManager` 是一次远征内唯一的 World / Battle 上层协调器。
- `WorldManager` 拥有地图、房间与 encounter facts，不拥有 Battle lifecycle。
- `BattleManager` 拥有一场 Battle，不拥有地图或长期 progression。
- `BattleSystem` 常驻于 `ExpeditionSystem`；每场 Battle 必须显式建立并清理临时状态。
- `Timeline` 拥有逻辑调度，不拥有 EnemyAI 决策或伤害真相。
- `EnemyAI` 拥有规划 / decision state；`EntityManager` / `CombatEntity` 拥有执行边界与战斗数值。
- `CardManager` 拥有逻辑牌堆；Card UI 不拥有 pile membership。
- `CardData → CardInstance → RuntimeCard` 是有意的生命周期分层，不应合并。
- Presentation 反映 gameplay state，但不拥有 gameplay truth。
- `SaveManager` 只提供通用存档基础设施；业务状态由对应 gameplay owner / adapter 提供。
- Expedition persistence 使用一个远征级边界，不创建独立 World-save 与 Battle-save 真相。
- 试玩版 Battle transient state 不是持久化真相；Battle 中断从 Battle Start Checkpoint 整场重开。
- 不为方便创建第二个全局状态 owner。
- `[TARGET]` 在真实实现与验证完成前不得写成 `[LIVE]` 或 `[SOURCE]`。

## 24. Maintenance rules

以下变化需要更新本文：

- major system responsibility 或 authoritative owner 改变；
- 重要 SceneTree 组合或 exported binding 改变；
- World / Battle / Card / Entity / Save 的跨系统 data flow 改变；
- encounter、battle result、action、checkpoint 等重要 boundary contract 改变；
- save ownership 或恢复粒度改变；
- `[TARGET]` 架构真正实现；
- legacy 路径被替换并不再影响人工理解。

通常不因为以下变化更新本文：

- balance values、卡牌数值或内容数量；
- 当前 milestone、任务优先级或制作排期；
- private helper refactor；
- 纯视觉调优；
- 只影响精确导航的文件移动。

精确代码导航由 `CODEMAP` 维护，项目概览与当前状态由 `README` 维护，玩法与设计由 `GAME_DESIGN` 维护。更新架构时，应重新读取真实文件并维持 `[LIVE] / [SOURCE] / [TARGET] / [LEGACY] / [VERIFY]` 的证据边界。
