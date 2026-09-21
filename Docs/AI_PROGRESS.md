# AI_PROGRESS.md

> **文件作用（给人和 AI）：**这是项目的“当前工作台”。它只记录现在做到哪里、正在解决什么、哪些问题阻塞下一步、下一阶段准备做什么，以及最近已经实际验证过什么。
>
> **它不负责：**
> - 定义长期系统职责：见 `AI_CONTEXT.md`
> - 展示 SceneTree / 脚本契约 / runtime data flow：见 `ARCHITECTURE.md`
> - 保存全部代码定位信息：见 `CODE_INDEX.md`
> - 保存玩法、数值与机制规则：见 `MECHANICS.md`
> - 规定 Agent 工作方式：见 `AGENTS.md`
>
> **更新原则：**这是动态文档，不是历史日志。完成一个明显里程碑、发现/解决关键阻塞、完成一次真实验证，或当前工作重点改变时更新；旧历史交给 Git / issue / 看板。
>
> **当前基线日期：**2026-09-21  
> **当前活动工作区：**`D:/Game project/Godot/LW_game_development_upgrade_test`  
> **当前开发引擎：**Godot 4.7.2 stable

---

# 0. 当前工作重点

## 0.1 当前正在进行

当前阶段首先在建立一套可长期使用的 Codex + Godot 工程工作流，并同步刷新项目指导文档。

目前已经完成或基本完成：

```text
Godot 4.7.2 升级测试环境
→ canonical Godot CLI wrapper
→ MCP Editor Bridge 连通
→ AI_CONTEXT.md 刷新
→ ARCHITECTURE.md 初次真实源码审计
```

当前文档刷新顺序：

```text
AI_CONTEXT.md          [已完成]
ARCHITECTURE.md        [已完成第一轮源码审计]
AI_PROGRESS.md         [当前]
CODE_INDEX.md          [下一份]
MECHANICS.md           [之后]
```

完成指导文件刷新后，再继续：

```text
Runtime MCP 端到端验证
→ 工具/环境收口
→ 游戏纵向闭环实现
```

---

## 0.2 下一阶段 gameplay 里程碑

已确定的主 gameplay 目标仍然是：

```text
地图探索
→ 遭遇敌人
→ ExpeditionManager 接管交接
→ 进入 BattleSystem
→ 战斗结束
→ BattleResult 返回 ExpeditionManager
→ 更新同一次 World map / RoomData
→ 回到探索
→ 继续同一次远征
```

该闭环完成前，不应优先扩展大量新玩法系统。

### 纵向闭环验收目标

- 一次遭遇只启动一次战斗。
- 探索状态只暂停/恢复一次。
- 玩家数据、牌组和 `EnemyID` 只交接一次。
- `BattleManager` 只初始化一次。
- `battle_ended` 结果只处理一次。
- 战斗结果回到同一次 expedition / 同一份 `mapdata`。
- 已处理房间的遭遇状态得到更新。
- 返回探索后移动、镜头与输入恢复。
- 上一场战斗的 queue、临时 Buff、signals、callbacks、visual waits、input locks 不泄漏到下一场。

---

# 1. 工程与工具当前状态

## 1.1 Godot

- 当前开发版本：Godot `4.7.2 stable`
- 4.4.1 原项目继续作为安全回退项目。
- 当前 main scene：
  `res://MainMenuSystem/MainMenu.tscn`
- 旧失效 main-scene UID 问题已解决。

## 1.2 Canonical CLI

标准入口：

```powershell
.\tools\godot_cli.ps1 <Godot args>
```

已实际验证：

```text
wrapper
→ 找到 Godot 4.7.2 console executable
→ --version 正确返回 4.7.2
→ 创建 .codex_runtime/
→ --headless --editor --path . --quit 可完成 editor 初始化并正常退出
```

`.codex_runtime/` 当前至少包含：

```text
AppData/
Temp/
```

其用途是隔离 Codex / Godot 自动化运行产生的用户与临时数据。

### 尚需最终确认

- `.codex_runtime/` 是否已经正式加入当前工作区 `.gitignore`
- wrapper 是否已经纳入最终 Git checkpoint

以上不影响当前使用，但在最终环境收口时应检查。

---

## 1.3 MCP

### Editor Bridge

此前已经完成 Editor MCP 连通验证：

- MCP server 正常
- Editor Bridge connected
- Godot version 4.7.2
- 能读取当前打开场景与 editor info

### Runtime Bridge

Godot 输出中已经观察到：

```text
[godot-mcp-runtime] Listening on 127.0.0.1:9877
```

但仍缺少正式的 Runtime MCP 端到端验证，例如：

```text
runtime_ping
runtime_get_tree（小范围）
```

因此：

```text
Editor MCP        = 已验证
Runtime listener  = 已出现
Runtime MCP E2E   = 待验证
```

---

# 2. 当前真实架构状态摘要

> 详细结构、函数签名和数据流见 `ARCHITECTURE.md`。本节只保留影响当前开发优先级的事实。

| Area | 当前状态 | 说明 |
| --- | --- | --- |
| `GameManager` | ⛔ 占位 | 当前没有应用流程实现 |
| `ExpeditionManager` | ⛔ 占位 / 未挂载 | 目标职责已确认，但当前尚未进入真实 SceneTree |
| `PlayerSaveManager` | ⛔ 占位 / 未挂载 | 长期玩家数据 owner 已确认，但实现尚未开始 |
| `SaveManager` | 🟡 基础框架存在 | slot / module registry / JSON file I/O 已有 |
| `WorldManager` | 🟡 部分完成 | 地图和探索逻辑存在，但尚未把 encounter 上报给 ExpeditionManager |
| `WorldGenerator` | 🟢 基础主要逻辑存在 | 生成 mapdata / RoomData / doors |
| `RoomSet / DoorSet` | 🟢 基础结构存在 | 动态生成房间与门 |
| `PlayerVisualManager` | 🟢 基础表现控制存在 | 探索移动/镜头模式已有 |
| `BattleManager` | 🟡 代码存在 / 场景接线阻塞 | battle orchestration 已写较多，但关键 exports 未绑定 |
| `Timeline` | 🟢 核心逻辑存在 | logical time / action queue / wait lifecycle |
| `EntityManager` | 🟡 部分完成 | action execution 存在；`enemy_ai` 当前场景未绑定 |
| `EnemyAI` | 🟡 部分完成 | initial planning 有；continuous planning 未接通 |
| `CardManager` | 🟢 主要牌堆逻辑存在 | draw / hand / discard authority |
| Card UI | 🟢 基础结构存在 | RuntimeCard UI / interaction / animation 路径存在 |
| `BattleSaveModule` | 🔴 Legacy | 当前数据模型不兼容，不作为新架构依据 |
| Expedition-level save module | ⬜ 未实现 | 已确认长期目标 |

---

# 3. 已解决的旧 P0

## 3.1 主场景 UID

旧状态：

```text
run/main_scene = uid://0rtgdscsodly
```

该 UID 已失效。

当前已经修复为：

```text
res://MainMenuSystem/MainMenu.tscn
uid://cu8ebs30en5qs
```

状态：

```text
RESOLVED
```

---

## 3.2 Godot 4.4.1 MCP 兼容问题

旧版 Godot 4.4.1 无法解析当前 `godot-mcp` plugin 使用的一些更新 Editor API。

当前处理方式：

```text
4.4.1 original project
→ 保留为 fallback

4.7.2 upgrade_test
→ 当前开发 workspace
```

Godot 4.7.2 中 Editor MCP 已正常加载。

状态：

```text
RESOLVED BY UPGRADE TEST WORKSPACE
```

---

## 3.3 Codex Godot CLI 环境

此前自动化 Godot CLI 会遇到用户目录 / temp / console executable 等问题。

当前：

```text
tools/godot_cli.ps1
+
.codex_runtime/
+
Godot 4.7.2 console executable
```

已完成核心 headless editor 验证。

状态：

```text
RESOLVED FOR CURRENT WORKFLOW
```

---

# 4. 当前 P0：阻塞纵向 gameplay 闭环

## P0-1 `ExpeditionManager` 尚未真正进入场景

当前保存态：

```text
ExpeditionSystem
├─ WorldSystem
└─ UISystem
```

没有：

```text
ExpeditionManager
BattleSystem instance
Expedition-level save module
```

而目标架构要求：

```text
ExpeditionSystem
├─ ExpeditionManager
├─ WorldSystem
├─ BattleSystem        # resident
├─ UISystem
└─ expedition save adapter/module
```

### 影响

当前没有真正的：

```text
World → Expedition → Battle
Battle → Expedition → World
```

上层协调对象。

---

## P0-2 `BattleSystem.tscn` 存在 legacy 断引用与关键 export 未绑定

当前保存态仍有：

```text
CombatManager node
→ missing CombatManager.gd reference
```

这属于 legacy 断引用，不应通过重新恢复第二个战斗总管理器来解决。

当前 `BattleManager`：

```text
timeline         = 未绑定
entity_manager   = 未绑定
card_manager     = UI/CardSystem [已绑定]
battle_save_module = 未绑定
```

当前 `EntityManager`：

```text
player_entity = 已绑定
enemy_entity  = 已绑定
enemy_ai      = 未绑定
```

### 影响

即使存在 `BattleManager.start_battle()`，当前保存的场景 wiring 也无法完整运行预期战斗链。

---

## P0-3 World → Battle 没有正式交接接口

当前 `WorldManager` 遭遇流程仍然内部切换：

```text
door opened
→ target RoomData
→ PREPARING_BATTLE
→ timer
→ enter_battle_mode()
```

当前没有：

```text
EncounterFact
encounter signal
ExpeditionManager handoff
BattleManager.start_battle()
```

`enter_battle_mode()` 目前也没有真正启动战斗。

---

## P0-4 Battle → World 没有结果闭环

当前：

```text
BattleManager
→ battle_ended(is_player_victory: bool)
```

但：

```text
receiver = none
```

目前工程中也没有正式的：

```text
BattleResult
```

数据类型/契约。

`WorldManager.finish_battle()` 存在，但没有连接到真实 Battle result flow。

---

# 5. 当前 P1：战斗内部已知问题

## P1-1 EnemyAI 只有 initial planning 链

当前存在：

```text
setup_ai()
→ plan_initial_actions()
→ plan_next_action(0)
→ action_planned(CombatAction)
```

但尚未形成：

```text
action completed
→ next plan trigger
→ plan_next_action(current_time)
```

的持续闭环。

此外，当前 `EntityManager.enemy_ai` 未绑定，因此保存态甚至无法通过该引用启动首次规划。

---

## P1-2 stamina / mana 支付规则不一致

当前：

```text
RuntimeCard
attack → stamina_cost
other  → mana_cost
```

但 `BattleManager` 当前出牌校验与扣费固定使用：

```text
"stamina"
```

### 需要的后续设计决定

在修复前需要明确：

```text
Attack / Skill / Power
分别使用什么资源
```

不要仅为了消除报错而任意选择。

---

## P1-3 CardBuff 存在双路径施加风险

当前同一 `CombatAction.card_buffs` 存在两条路径：

```text
EntityManager.execute_action()
→ card_buff_requested
→ BattleManager
→ CardManager
```

以及：

```text
BattleManager._on_timeline_action_triggered()
→ 直接处理 action.card_buffs
```

需要统一为一个权威结算路径。

---

## P1-4 `CardInstance` → `RuntimeCard` 数据未完整继承

当前 `BattleManager.start_battle()` 转换主要使用：

```text
card_id
card_data
```

`CardInstance.modifiers` / `unique_id` 当前没有完整进入 `RuntimeCard`。

这是否属于 bug，取决于长期 CardInstance / RuntimeCard 设计，应结合 `MECHANICS.md` 与未来卡牌持久化设计一起确认。

---

## P1-5 `RuntimeCard` 存档内容不完整

当前 `RuntimeCard.to_dictionary()` 不保存：

```text
active_buffs
```

这在未来决定“战斗中途可恢复”的存档粒度时需要处理。

当前不阻塞纵向探索↔战斗里程碑。

---

# 6. Save 当前状态

## 6.1 当前实现

`SaveManager`：

```text
slot
metadata
module registry
JSON I/O
```

基础存在。

`BattleSaveModule.gd`：

```text
file exists
but not mounted
not registered in current chain
data model incompatible
legacy
```

当前已知 legacy 问题包括：

- 与 `EntityData` 当前 constructor / fields 不兼容；
- 与 `EnemyData` 当前 fields 不兼容；
- `BattleManager` 曾期待 `save_initial_state(...)`，但 module 没有该接口；
- 当前不应为了别的任务顺便修补。

## 6.2 已确认目标

最终：

```text
SaveManager
├─ PlayerSaveManager adapter
└─ Expedition-level Save Module
```

而不是：

```text
World save truth
+
Battle save truth
```

各自独立。

当前原型阶段：

```text
旧存档兼容 = 非要求
```

因此未来可以优先建立干净的新 expedition snapshot contract。

---

# 7. 当前文档与 Agent 工作流状态

| File | 当前状态 | 下一动作 |
| --- | --- | --- |
| `AGENTS.md` | 已完成工作流规则升级 | 后续若规则改变再更新；每次修改必须向用户报告 |
| `AI_CONTEXT.md` | 已刷新 | 稳定职责/ownership 改变时更新 |
| `ARCHITECTURE.md` | 已完成第一轮真实源码审计 | Editor/Runtime 实际状态改变时增量维护 |
| `AI_PROGRESS.md` | 本次刷新 | 每个明显 milestone 后更新 |
| `CODE_INDEX.md` | 旧版仍含过期内容 | **下一份处理** |
| `MECHANICS.md` | 尚未刷新 | CODE_INDEX 后处理 |

`PROJECT_DUMP.md` / `build_godot_snapshot.py`：

```text
Web model workflow only
```

不属于 Codex Agent 的实时工程事实来源。

---

# 8. ARCHITECTURE 当前验证边界

本轮 `ARCHITECTURE.md` 刷新时 Godot Editor 没有打开，因此 Editor MCP 未参与该次审计。

这不会使当前架构文档失效，因为：

```text
project.godot
.tscn
.gd
.tres
```

足以确认“磁盘保存态”的 SceneTree、attached scripts、export values 和源码契约。

但以下内容仍不能据此声明 runtime 已验证：

- 未保存的 Editor 临时状态；
- runtime 动态 SceneTree；
- signal 实际是否按预期触发；
- battle flow 是否实际可跑通；
- runtime-only data flow；
- Inspector 中尚未保存的改动。

因此当前原则是：

```text
saved project structure
= 可作为当前事实

runtime behavior
= 仍需运行验证
```

不需要为了这一点重做整份 `ARCHITECTURE.md`。

---

# 9. 接下来推荐的工作顺序

## 当前文档收口

```text
1. AI_PROGRESS.md      ← 当前完成
2. CODE_INDEX.md
3. MECHANICS.md
```

## 工具收口

```text
4. Runtime MCP E2E validation
5. 检查 .gitignore / .codex_runtime/
6. 可选：tools/codex_doctor.ps1
7. Git checkpoint
```

## Gameplay implementation

```text
8. 清理 BattleSystem scene wiring blockers
9. 实现 ExpeditionManager 最小纵向协调
10. World encounter → Expedition handoff
11. Expedition → Battle start
12. Battle result → Expedition
13. Expedition → same World/RoomData restore
14. 第二场战斗 lifecycle cleanup 验证
```

之后再处理非纵向闭环必要的 P1 战斗问题。

---

# 10. 最近实际验证记录

## 2026-09-21 — Godot 4.7.2 CLI

已验证：

```text
Godot console executable --version
→ 4.7.2 stable
```

## 2026-09-21 — canonical wrapper

已验证：

```powershell
.\tools\godot_cli.ps1 --version
```

结果：

```text
wrapper 找到正确 4.7.2 console executable
version 正确
```

## 2026-09-21 — `.codex_runtime`

已验证：

```text
.codex_runtime/
├─ AppData/
└─ Temp/
```

## 2026-09-21 — headless editor initialization

已验证：

```powershell
.\tools\godot_cli.ps1 --headless --editor --path . --quit
```

观察：

```text
Godot 4.7.2 启动
filesystem scan DONE
editor layout load DONE
Godot MCP plugin loaded
Godot MCP plugin unloaded
process returned to PowerShell normally
```

这证明 wrapper 与 headless editor initialization 可以正常工作。

它**不等于** gameplay runtime 闭环通过。

---

# 11. 已知但当前故意不处理

## `BattleSaveModule.gd`

这是 legacy 代码，计划被新的 expedition-level save architecture 替代。

当前已知 parser/type compatibility 问题可以作为迁移例外记录，不应为了“让项目看起来零错误”而在无关任务中修复。

## 旧 CardEffect 路径

如果当前工程仍同时保留：

```text
CardData / CardEffect legacy path
```

与：

```text
RuntimeCard → CombatAction
```

不要在没有明确迁移任务时大范围删除。

先确认 gameplay effect architecture，再统一清理。

---

# 12. 当前完成定义

当前 workflow/documentation 阶段在以下条件满足后可以视为收口：

- [x] Godot 4.7.2 active workspace 可用
- [x] canonical CLI wrapper 可用
- [x] headless editor initialization 验证
- [x] Editor MCP 基础连通验证
- [x] `AI_CONTEXT.md` 刷新
- [x] `ARCHITECTURE.md` 第一轮真实源码审计
- [x] `AI_PROGRESS.md` 刷新
- [ ] `CODE_INDEX.md` 刷新
- [ ] `MECHANICS.md` 刷新
- [ ] Runtime MCP E2E 验证
- [ ] `.gitignore` / generated runtime data 最终确认
- [ ] 最终 Git checkpoint

完成后即可把主要精力切回 gameplay vertical slice。
