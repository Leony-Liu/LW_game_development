# AGENTS.md

Stable project map and collaboration contract for Web GPT and Desktop Codex.
Keep this file compact, generic, and slow-changing. It defines how AI collaborators reason about and work on the repository; it is not a project status log, gameplay specification, architecture reference, schedule, or code index.
Do not modify it unless the user explicitly changes the collaboration workflow or repository-wide rules.

## Communication

- Report to the user in Simplified Chinese unless explicitly requested otherwise.
- Keep code identifiers, class names, methods, signals, file paths, CLI commands, and exact tool/status strings in their original form.
- Keep completion reports concise and factual.
- Do not invent gameplay, product, save, or architecture decisions when requirements are unresolved.

## GDScript 中文注释与可维护性规范

Codex 新建或实质修改 `.gd` 脚本时，使用**简体中文、短句注释**；代码标识符与 Godot API 保持原样。

- **脚本开头**：仅用 2～3 行概述用途和职责，不写使用教程或大段修改指南。
- **方法前**：每个方法用 1 行短句说明作用及关键运行机制；仅在确有歧义时补充必要信息。
- **方法内部**：只在关键分支、状态变更、跨系统交接和不直观的实现处使用单行注释，说明原因或影响；不逐行翻译代码。
- **方便修改**：需要特别定位的配置或逻辑入口，用 1 行注释指出可修改的字段、方法或影响范围；优先利用清晰命名和 Inspector 分组。
- **简洁准确**：避免连续多行、重复说明、装饰性分隔线和无必要注释；注释与实际代码保持同步，不把待实现功能写成已完成。
- **修改范围**：仅为新增或本任务涉及的脚本补注释，不批量改写无关脚本。

## Canonical project documents

Use only the document relevant to the question. Do not load the entire set by default.

| Document | Read when you need |
| --- | --- |
| `/AGENTS.md` | Stable collaboration rules, source-of-truth policy, and repository workflow |
| `Docs/README.md` | Project overview, current environment, current stage, blockers, and immediate direction |
| `Docs/GAME_DESIGN.md` | Intended gameplay, player experience, Demo/full-game scope, balance intent, or design TBDs |
| `Docs/ARCHITECTURE.md` | System responsibilities, state ownership, important SceneTree composition, contracts, and cross-system flow |
| `Docs/CODEMAP.md` | Task-oriented navigation to likely real source, scene, and resource files |

The personal GDD and production planning material are external to this repository knowledge system. They are not Desktop Codex dependencies unless the user explicitly provides them for a task.

## Collaboration model

### Web GPT

- Discusses design and architecture with the user.
- Uses the canonical documents and factual Codex reports.
- Plans the next implementation task and writes scoped Codex instructions.
- Reviews results and identifies decisions that need user confirmation.
- Must not assume unverified local repository state.

### Desktop Codex

- Reads this file first and routes to the minimum relevant canonical documents.
- Uses `Docs/CODEMAP.md` before broad repository search.
- Inspects the real workspace, and Editor / Runtime state when the task requires them.
- Performs scoped changes, validates them proportionately, and preserves unrelated user work.
- Updates only documentation whose owned information materially changed.
- Returns a concise factual report, including validation limits and unresolved decisions.

## Authority and source of truth

### Gameplay and player experience

1. Explicit user decisions in the current task.
2. `Docs/GAME_DESIGN.md`.

Current code does not redefine confirmed design. If implementation and confirmed design differ, report an implementation gap. Never resolve a `【待设计】`, TBD, pending, or equivalent item without user confirmation.

### Architecture

1. Explicit user decisions in the current task.
2. Confirmed rules in `Docs/ARCHITECTURE.md`.

Never treat `[TARGET]` architecture as already implemented.

### Current implementation

Trust, in order:

1. Real workspace files.
2. Current Godot Editor state when relevant.
3. Current Runtime state when relevant.
4. Documentation summaries.

If documentation conflicts with verified implementation facts, report the mismatch. Do not change unrelated code merely to make it match stale documentation.

### Current project status

Use `Docs/README.md`. It is a current summary, not a substitute for inspecting real files.

## Stable project principles

- Keep design truth separate from implementation truth.
- Prefer minimal, readable, maintainable changes that preserve behavior outside the task.
- Prefer data-driven configuration for values expected to be tuned repeatedly.
- Respect established state ownership; do not create a second global owner for convenience.
- Required dependencies and invalid data must fail clearly; do not hide them with silent defaults or skipped calls.
- Every lifecycle entry path needs corresponding success, failure, cancellation, and cleanup handling.
- `GameManager` owns application-level flow such as Base / MainMenu ↔ Expedition.
- `ExpeditionManager` is the sole upper coordinator for World ↔ Battle inside one expedition.
- `WorldManager` owns current map, room, and encounter facts.
- `BattleManager` owns one battle, not map state or long-term progression.
- `Timeline` owns logical scheduling, not EnemyAI decisions or damage truth.
- Presentation reflects gameplay state but does not own gameplay truth.
- `CardData → CardInstance → RuntimeCard` is an intentional lifecycle separation.
- `SaveManager` owns generic save infrastructure, not gameplay-specific state.
- Verify only as deeply as necessary to prove the task; do not claim runtime behavior from parsing or scene loading alone.

## Desktop Codex workflow

### Navigation

1. Read `Docs/CODEMAP.md` to locate the likely implementation area.
2. Read the real files it points to.
3. Read `Docs/GAME_DESIGN.md` when gameplay meaning matters.
4. Read `Docs/ARCHITECTURE.md` when ownership, SceneTree, public contracts, signals, or cross-system flow matters.
5. Read `Docs/README.md` when current stage, blockers, environment, or recent verification matters.
6. Expand to targeted repository search only when the map is missing, stale, or insufficient.

Do not depend on generated source snapshots as current runtime truth.

### Before editing

- Inspect `git status` and treat existing uncommitted changes as intentional.
- Inspect the relevant real source, scene, resource, or configuration files.
- Identify the minimum file set and check whether the requested behavior already exists in another form.
- Do not modify unrelated files or perform unrelated refactors, migrations, renames, cleanup, or formatting passes.
- Do not repair or remove legacy systems unless they are in scope or a hard dependency.
- Do not add Autoloads, global managers, architectural layers, or third-party dependencies without a clear task requirement.
- Do not hardcode secrets, credentials, or machine-specific paths into gameplay code.
- When scripts, scenes, or resources change, verify relevant NodePaths, signals, exported references, animation tracks, resource references, and UIDs; never invent UIDs manually.
- Treat the fallback project identified in `Docs/README.md` as protected unless the user explicitly asks to modify it.

### Godot validation

Canonical CLI entry point:

```powershell
.\tools\godot_cli.ps1 <Godot args>
```

Use the smallest validation that proves the task:

1. Relevant source/static inspection.
2. Targeted Godot CLI validation.
3. Targeted scene run or temporary probe when behavior requires it.
4. Editor MCP when current editor state matters.
5. Runtime MCP when live runtime behavior must be observed.

Prefer targeted runtime inspection over broad SceneTree dumps. Temporary probes must not remain as gameplay source unless explicitly requested.
Save validation must use isolated test data and must not overwrite user saves.

### Godot test process cleanup

- Track PIDs for Godot processes launched by Codex for automated validation, including headless probes.
- Ensure these test processes exit after success, failure, or timeout; use graceful termination first and force-stop only Codex-owned test processes when necessary.
- Verify that no Codex-launched test process remains and that its MCP ports (such as `9876` / `9877`) are no longer held by that process.
- Never terminate the user's Godot Editor, active game session, or any unrelated process; identify process ownership before cleanup.
- If cleanup is unsafe or unsuccessful, report the PID, command line, occupied port, and reason. Do not claim cleanup succeeded without verification.

### Repository and Git safety

- Never discard, overwrite, revert, or normalize unrelated user changes.
- Do not create commits, branches, tags, merges, rebases, or pushes unless explicitly requested.
- Do not modify `.gitignore`, `.gitattributes`, repository tooling, or shared infrastructure unless required by the task.
- Human developers control final Git history.

### Documentation maintenance

Update only the document whose responsibility changed:

- `README.md`: current stage, blocker, environment, immediate direction, or important verification.
- `GAME_DESIGN.md`: explicit user-approved gameplay or scope decision.
- `ARCHITECTURE.md`: ownership, important SceneTree, public contract, or cross-system data flow.
- `CODEMAP.md`: important path, entry point, or navigation guidance.

Do not maintain deprecated parallel documents.

## Completion report

Report in Simplified Chinese:

- what changed;
- files changed;
- validation performed and results;
- Godot test-process cleanup status, including any remaining PID or MCP port conflict;
- unresolved issues, decisions, or material documentation/implementation mismatches.

Never claim more than was actually verified.
