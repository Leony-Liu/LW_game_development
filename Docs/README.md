# LW_game_development

本文件是项目的快速首页，面向用户、Web GPT、Desktop Codex 与其他开发者。它说明项目是什么、当前环境是否可用、开发做到哪里、主要缺口是什么，以及接下来应从哪里继续。

详细内容由其他规范文档负责：

- 协作规则与文档路由 → `/AGENTS.md`
- 玩法、体验和 Demo / full-game 设计 → `Docs/GAME_DESIGN.md`
- 系统关系、状态归属和实现边界 → `Docs/ARCHITECTURE.md`
- 精确代码导航 → `Docs/CODEMAP.md`

## 1. 项目概况

`LW_game_development` 是一款以**第一人称程序生成远征、逻辑行动轴卡牌战斗和“武器即牌组”构筑**为核心的游戏。

当前开发目标是先打通可靠的探索 ↔ 战斗纵向闭环，再扩展更多 gameplay 内容。

| 项目 | 当前值 |
| --- | --- |
| 活动工作区 | `D:/Game project/Godot/LW_game_development_upgrade_test` |
| 活动分支 | `upgrade/godot-4.7-test` |
| 开发引擎 | Godot `4.7.2 stable` |
| 主场景 | `res://MainMenuSystem/MainMenu.tscn` |
| 主场景 UID | `uid://cu8ebs30en5qs` |
| 受保护回退项目 | `D:/Game project/Godot/LW_game_development` |
| 回退引擎 / 标签 | Godot `4.4.1` / `godot-4.4.1-safe` |

本文是当前状态摘要，不替代真实工作区。涉及当前源码、场景、Inspector、Resource 或运行时行为时，应重新检查对应文件或 Godot 状态。

## 2. 主要工程区域

| 区域 | 作用 |
| --- | --- |
| `MainMenuSystem/` | 当前应用入口；正式 Application flow 尚未完成 |
| `ExpeditionSystem/` | 一次远征的顶层组合，包括 World、resident Battle 和 UI |
| `ExpeditionSystem/WorldSystem/` | 地图生成、房间与门、探索移动和相机 |
| `ExpeditionSystem/BattleSystem/` | Battle lifecycle、Timeline、EnemyAI、Entity、Card 和 battle UI |
| `Scripts/` | 全局管理器、静态数据加载器、共享 Resource / RefCounted 类型 |
| `Docs/` | 项目规范文档；精确文件入口见 `CODEMAP.md` |
| `tools/` | Godot CLI 等开发验证工具 |

## 3. 当前开发阶段

当前 gameplay 主线是完成一次完整的：

```text
地图探索
→ 遭遇敌人
→ ExpeditionManager 接管交接
→ BattleSystem
→ 战斗结束
→ 结果返回 ExpeditionManager
→ 更新同一次 World / mapdata / RoomData
→ 恢复探索
→ 继续同一次远征
```

这条纵向闭环尚未完成，因此当前不应把“场景已装配”误认为“完整 gameplay 已验证”。

## 4. 已完成的关键基础

### Expedition / Battle 顶层装配

当前保存场景已经包含：

```text
ExpeditionSystem
├─ ExpeditionManager
├─ PrototypePlayerDataProvider
├─ WorldSystem
├─ BattleSystem
└─ UISystem
```

已确认：

- `BattleSystem` 是 `ExpeditionSystem` 的常驻子场景。
- `ExpeditionManager` 已绑定 World、Battle 与 prototype provider。
- `BattleManager` 已绑定 Timeline、EntityManager 与 CardManager。
- `EntityManager` 已绑定 player、enemy 与 EnemyAI。
- 旧 `CombatManager` 节点及缺失脚本引用已移除。

这些接线已经过定向场景加载 / probe 验证，但完整 battle lifecycle 尚未运行验证。

### Prototype player / deck input

`PrototypePlayerDataProvider` 当前可从显式 Inspector 配置生成：

```text
player fields → EntityData
CardData IDs → AllCardData lookup → CardInstance[]
```

默认未配置时不会伪造数据；无效 Card ID 会明确失败且不返回部分牌组。保存配置、字段映射、空牌组、重复有效 Card ID 与无效 Card ID 已通过隔离运行探针验证。该 provider 是原型期临时输入，不是长期玩家数据 owner。

### World encounter reporting

`WorldManager` 现在通过 `encounter_requested(room_data, enemy_id)` 向 `ExpeditionManager` 上报有效遭遇。请求期间使用门闩拒绝重复或重入上报；空房间、无敌房间、无效 / 不存在的敌人 ID 会明确失败。

`ExpeditionManager` 已完成 M1-03 Battle startup handoff：校验原 `RoomData`、provider 与 Battle 状态，组装 `EntityData + CardInstance[] + enemy_id`，并仅在 `BattleManager.start_battle()` 明确返回成功后接受 encounter。失败请求会释放，World 保持可重试状态。

M1-04 Exploration-to-Battle transition 及第一人称遇敌接近补充已完成：World 依次进入 `EXPLORE → PREPARING_BATTLE → BATTLE`；准备期停用手动移动与视角，保留原第一人称相机，并让真实 `CharacterBody3D` 沿碰撞几何接近原 `RoomData` 对应房间的敌人锚点。玩家到达安全距离且身体 / 镜头朝向完成后才进入 `BATTLE`，Battle UI / 卡牌输入只在最终状态开放。transition id、原 `RoomData` 与目标节点身份共同拒绝旧回调和错误目标；Battle 的内部锁与远征表现门闩继续采用合并锁。

M1-05 Battle startup failure handling 已完成：encounter 返回最终接受结果，匹配请求在接受或拒绝后都会释放 pending；`ExpeditionManager` 在启动前额外预检敌人锚点和玩家表现依赖，并允许修正配置后重试；`BattleManager` 在任何 Entity、Timeline、牌堆或卡牌 UI 写入前完成 Entity / Card 预检，并拒绝重入及已激活 Battle。正常启动、四个接近方向、旧回调、错误房间、无效 / 释放目标与 Battle 表现门闩已通过隔离运行探针验证。实际镜头手感仍需在可视窗口中人工验收。

因此 M1-01 至 M1-05 的“探索遇敌并可靠进入 Battle”启动阶段可视为完成；这不包含战斗结果返回、正常恢复探索或第二场 Battle cleanup。

### Battle 内部基础

当前已有：

- `Timeline` logical time / action queue 基础；
- `EntityManager` 初始化与 action execution 基础；
- `CardManager` draw / hand / discard 基础；
- Card UI / interaction / animation 基础；
- `EnemyAI` initial planning 基础。

## 5. 当前主要缺口

### Battle → Expedition → World

`BattleManager` 已发出 `battle_ended(is_player_victory: bool)`，但没有正式 receiver，也没有完整 result contract。

战斗结束后保持同一 `mapdata`、更新原 `RoomData`、恢复探索移动 / 镜头 / 输入的闭环尚未实现。

Battle 已激活后若准备阶段被外部强制中断，目前没有安全的取消 / rollback contract。旧计时器不会恢复 UI 或输入，但 Battle 会保持 active、隐藏且锁定；该状态需要后续正式 cleanup / result lifecycle 处理，不能视为可重试启动失败。

### Battle 内部已知问题

- `EnemyAI` continuous planning 尚未形成完整循环。
- stamina / mana 当前支付路径不一致。
- `CardBuff` 存在重复施加路径风险。
- `CardInstance → RuntimeCard` 尚未完整继承 `modifiers / unique_id`。
- resident BattleSystem 的第二场战斗 cleanup 尚未验证。

最终玩法语义以 `GAME_DESIGN.md` 为准；实现边界和 owner 见 `ARCHITECTURE.md`。

## 6. 存档当前状态

`SaveManager` 已具备 slot、metadata、module registry 与 JSON file I/O 基础。

长期方向是：

```text
SaveManager
├─ persistent player data adapter
└─ one expedition-level checkpoint module
```

试玩版恢复边界已经确定为 Room Entry Checkpoint 与 Battle Start Checkpoint；战斗中断后整场重开，不要求序列化战斗中途 transient state。

`BattleSaveModule.gd` 仍是未挂载且数据模型不兼容的 legacy 文件，不应作为新存档架构基础。`PlayerSaveManager.gd` 仍是 placeholder。

## 7. 工具链与验证边界

当前已验证：

| 能力 | 状态 |
| --- | --- |
| 真实项目文件访问 | 可用 |
| Godot 4.7.2 工作区 | 可用 |
| Canonical Godot CLI wrapper | 已验证 |
| Editor MCP | 已验证 |
| Runtime MCP direct access | 已验证 |
| Headless editor initialization | 已验证 |

Canonical CLI：

```powershell
.\tools\godot_cli.ps1 <Godot args>
```

已知工具例外：`get_status` 可能把 Runtime Bridge 汇总为 `not running / not enabled`，即使 `runtime_ping` 与 targeted runtime inspection 成功。判断 Runtime 是否可用时，应优先看直接调用结果。

`.codex_runtime/` 是自动化隔离目录，不属于 gameplay 源码。

当前验证不能自动证明以下行为完成：

- 人工窗口中的最终运镜手感与视觉品质；
- 完整 battle lifecycle；
- battle result return；
- 第二场战斗 cleanup；
- 完整探索 ↔ 战斗纵向闭环。

## 8. 当前直接开发方向

```text
1. Battle result → ExpeditionManager
2. 更新 same World / same mapdata / same RoomData
3. 恢复探索
4. 验证第二场战斗没有继承上一场 transient state
```

这是一条当前实现方向摘要，不是生产排期。

## 9. 重要注意事项

- `BattleSaveModule.gd` 是 legacy；不要为了无关任务顺手修补。
- 旧 `CardData → CardEffect` 路径仍与 `RuntimeCard → CombatAction` 并存；未经明确迁移任务不要扩展或批量删除。
- `ExpeditionSystem.tscn` 根节点名含不可见字符；精确导航风险见 `CODEMAP.md`。
- 当前工程状态、SceneTree 和运行行为以真实工作区为准，不以旧快照或本文摘要替代。

## 10. 文档导航

项目长期知识系统只包含：

| 文件 | 负责内容 |
| --- | --- |
| `/AGENTS.md` | Web GPT / Desktop Codex 共用协作契约、事实权威与工作方式 |
| `Docs/README.md` | 项目概览、当前环境、阶段、缺口与直接方向 |
| `Docs/GAME_DESIGN.md` | 游戏设计、体验规则、Demo / full-game scope 与设计 TBD |
| `Docs/ARCHITECTURE.md` | 实现架构、状态归属、系统关系、current / target 边界 |
| `Docs/CODEMAP.md` | Desktop Codex 使用的任务导向代码导航 |

## 11. 本文件何时更新

应更新：当前开发阶段、重要 blocker、环境 / branch / Godot 版本、直接开发方向、关键验证边界或重要 tooling exception 发生变化。

通常不更新：普通局部 bug fix、私有重构、数值微调、详细架构变化或完整历史记录。对应内容分别由真实代码、`GAME_DESIGN.md`、`ARCHITECTURE.md`、Git history / issue tracking 承担。
