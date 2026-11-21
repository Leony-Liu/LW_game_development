# System Registry

本表记录项目负责人已批准的 System / Subsystem 分类及当前实现状态。代码现状以真实工作区为准；未完成的边界不表示符合 `Docs/CODE_STANDARDS.md`。

| Approved boundary | Classification | Entry | Manager / current coordinator | Status |
| --- | --- | --- | --- | --- |
| GameManager | Application Flow Coordinator | 不适用 | `Scripts/GameManager.gd` | 应用流程协调器，不是正式 System |
| PlayerLoadoutSystem | Top-Level System | 待实现 | `Scripts/PlayerSaveManager.gd`（现有实现） | Entry 与正式边界待后续任务 |
| BaseSystem | Top-Level System | 待实现 | `BaseSystem/Scripts/Base.gd`（现有实现） | Entry 与正式边界待后续任务 |
| ExpeditionSystem | Top-Level System | `ExpeditionSystem/Scripts/expedition_system.gd`，附着于 `ExpeditionSystem/ExpeditionSystem.tscn` 根节点 | `ExpeditionSystem/Scripts/ExpeditionManager.gd`，内部子节点 | 应用层 Entry 已实现；子 Subsystem Entry 尚未接通，不视为全面符合标准 |
| WorldSystem | ExpeditionSystem 的 Subsystem | 待 R2.2 | `ExpeditionSystem/WorldSystem/Scripts/WorldManager.gd`（现有实现） | 父 Manager 仍直接调用现有 WorldManager |
| BattleSystem | ExpeditionSystem 的 Subsystem | 待 R2.3 | `ExpeditionSystem/BattleSystem/Scripts/BattleManager.gd`（现有实现） | 父 Manager 仍直接调用现有 BattleManager |
| CardSystem | BattleSystem 的 Subsystem | 待后续任务 | `ExpeditionSystem/BattleSystem/CardSystem/Scripts/CardManager.gd`（现有实现） | Entry 待实现 |
| EntitySystem | BattleSystem 的 Subsystem | 待后续任务 | `ExpeditionSystem/BattleSystem/EntitySystem/Scripts/EntityManager.gd`（现有实现） | Entry 待实现 |
| Workbench | ExpeditionSystem 的 Component | 不需要 | `Scripts/RefCounted/CardWorkbenchSession.gd` 等现有实现 | 内部 Component，不是 Subsystem |

## ExpeditionSystem 当前对外契约

- `initialize_player_data(ExpeditionInitializationRequest) -> ExpeditionInitializationResult`：来源武器为同步调用期间的只读共享引用；Manager 经 `ExpeditionPlayerData` 创建独立副本。
- `can_return_to_base() -> bool`：保留 Manager 的 debug 与探索状态校验。
- `is_extraction_pending(operation_id) -> bool`、`reject_extraction(ExpeditionExtractionRejectionRequest) -> bool`：保留操作身份及过期请求保护。
- `abort_failed_initialization()`：直接 Editor 启动失败时清理玩家数据并停用探索控制。
- 向应用层转发 `death_confirmed`、`return_to_base_requested`、`extraction_requested(ExpeditionExtractionRequestedEvent)`；撤离 Event 保留原 `operation_id`，并不表示结算完成。

`GameManager` 对 `PlayerSaveManager` 的直接调用以及 `ExpeditionManager` 对 World/Battle Manager 的直接调用仍是已知待迁移边界。`Docs/ARCHITECTURE.md` 在代码重构阶段冻结，待独立文档任务更新。
