# AGENTS.md

> Scope: entire repository. Explicit user instructions in the current conversation always take precedence.
>
> Purpose: stable operating contract for coding agents. It defines how to inspect, modify, validate, and protect this Godot project. It is not a task log and never overrides the real workspace state.

## 1. Core operating rules

1. **Inspect before editing.** Read the target file, callers, and relevant `.tscn` / `.tres`. Check `project.godot` when startup, Autoloads, input, rendering, or project settings are involved.
2. **Keep scope narrow.** Record unrelated problems; fix them only if they block the current task. Do not add speculative gameplay, abstractions, or refactors.
3. **One mutable state, one authoritative owner.** Do not duplicate runtime truth or add a second manager for a local problem.
4. **Respect architecture boundaries.** Exploration/battle handoff belongs to `ExpeditionManager`; battle-domain coordination belongs to `BattleManager`, unless the user explicitly changes the architecture.
5. **Check Godot wiring with script changes.** Verify signals, NodePaths, exported references, scene/resource references, animation tracks, and UIDs when relevant.
6. **Do not hide required-interface failures.** No `has_method`, null skipping, swallowed errors, fake defaults, or warning suppression to make required dependencies look valid.
7. **Every start path needs cleanup.** Success, cancellation, failure, and exit paths must not leak signals, callbacks, queues, visual waits, input locks, or stale scene references.
8. **Validate according to the change.** Never present static inspection as runtime validation; state what was and was not tested.
9. **Protect existing work.** Do not commit, push, publish, revert, overwrite, or clean unrelated user changes unless explicitly requested.

## 2. Source of truth and document use

Priority when information conflicts:

1. Explicit user instruction.
2. Current real workspace files and live Godot editor/runtime state.
3. `project.godot` for project configuration/wiring facts.
4. `Docs/AI_PROGRESS.md` for current milestone, blockers, and temporary exceptions.
5. `Docs/AI_CONTEXT.md` for architecture/system-map context.
6. `Docs/CODE_INDEX.md` for navigation.
7. `Docs/MECHANICS.md` for gameplay rules/design decisions.
8. Git history and explicitly provided external snapshots/notes, when relevant.

If documentation conflicts with current files, report the conflict. Do not modify code merely to match stale documentation.

Read only what the task needs:

- Use `Docs/CODE_INDEX.md` when locations are unknown, then inspect the real files.
- Read `Docs/AI_PROGRESS.md` before substantial work.
- Read `Docs/AI_CONTEXT.md` for ownership, scene composition, or cross-system work.
- Read `Docs/MECHANICS.md` only when gameplay rules/numbers matter.
- Do not mechanically load every project document into context.

## 3. Development environment and tool policy

### Active workspace

- Workspace: `D:/Game project/Godot/LW_game_development_upgrade_test`
- Godot editor: `D:/APP/Godot/4.7.2/Godot_v4.7.2-stable_win64.exe`
- Godot CLI backend: `D:/APP/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe`
- Canonical CLI wrapper: `tools/godot_cli.ps1`
- MCP server: `godot-mcp-472-test`

### Protected fallback

- Godot 4.4.1 project: `D:/Game project/Godot/LW_game_development`
- Treat it as protected fallback state. Do not modify, migrate, or open it with newer Godot unless the user explicitly requests this.

### CLI

`tools/godot_cli.ps1` is the **canonical CLI entry point** for automated Godot work in this repository.

Use it instead of the generic `godot` command or a directly invoked Godot executable:

```powershell
.\tools\godot_cli.ps1 --version
.\tools\godot_cli.ps1 --headless --path . --quit
.\tools\godot_cli.ps1 --headless --editor --path . --quit
```

Rules:

- Do not use the generic `godot` command; PATH may resolve to the protected Godot 4.4.1 installation.
- Do not bypass the wrapper by calling the 4.7.2 executable directly during normal agent work. Direct engine invocation is reserved for diagnosing the wrapper itself or when the user explicitly requests it.
- The wrapper must resolve the repository root, use the approved Godot 4.7.2 console executable, forward arguments, preserve the process exit code, and isolate automated user/temp data under `.codex_runtime/`.
- `.codex_runtime/` is generated automation state, never authored project content, and must remain ignored by Git.
- For clean `--editor` validation, avoid running a second interactive Godot editor when plugin ports or editor state could conflict.

### Tool order

Use the smallest tool surface/context that can complete the task:

1. Targeted file navigation/search.
2. Relevant real file reads.
3. Direct `.gd` / `.tscn` / `.tres` edits.
4. `tools/godot_cli.ps1` for Godot parsing/loading/running/validation.
5. Editor MCP only for real editor state or editor-only operations.
6. Runtime MCP only when live runtime state is required and the bridge is connected.

Editor MCP is appropriate for open scenes, scene trees, Inspector/exported properties, and editor wiring. Runtime MCP is appropriate for runtime trees/properties, method calls, input injection, pause/step, and runtime-only behavior.

### Context/token discipline

- No whole-project scan unless required.
- No full scene-tree dump when a narrow subtree is enough.
- No full logs when only errors are needed.
- No screenshots unless the issue is visual.
- Prefer targeted searches/reads and CLI validation over repeated broad MCP inspection.

## 4. Stable architecture boundaries

| Area | Authoritative owner | Must not own |
| --- | --- | --- |
| Application flow / base-expedition switching | `GameManager` | combat resolution, deck logic, map generation |
| Expedition lifecycle / explore-battle handoff | `ExpeditionManager` | map generation, single-action resolution, direct save-file I/O |
| Current map / room / encounter state | `WorldManager` | deck initialization, damage, long-term progression |
| Battle lifecycle / permissions / coordination | `BattleManager` | duplicated deck/entity state, map generation, direct file saving, card animation implementation |
| Draw / hand / discard runtime state | `CardManager` | win/loss ownership, entity-resource ownership, timeline ownership |
| Battle entity routing / attribute changes | `EntityManager` | deck ownership, timeline ownership, card animation, file saving |
| Exploration/battle/debug presentation | `PlayerVisualManager` | encounter rules, battle results, real combat values |
| Logical time / action queue | `Timeline` | damage, payment, saving, animation implementation |
| Static templates | `AllCardData` / `AllEnemyData` | current HP, temporary Buffs, live queues |
| Save slots / file I/O / module registration | `SaveManager` | gameplay decisions and reward calculation |

Core flows:

- Exploration/battle: `WorldManager -> ExpeditionManager -> BattleManager -> ExpeditionManager -> WorldManager`
- Battle action: `Card UI -> CardManager -> BattleManager -> EntityManager / CardManager / Timeline -> BattleManager -> presentation -> completion -> Timeline`

Invariants:

- One valid action pays once, moves a card once, and applies each effect once.
- Failed requests must not leave partially committed state.
- A stable `RuntimeCard` belongs to one logical pile at a time; visual nodes are not authoritative deck state.
- Logical time is separate from animation duration.
- Pause/skip/cancel/exit must resolve pending presentation waits explicitly.
- Template IDs and runtime-instance IDs are distinct.
- Do not silently decide unresolved same-time ordering, Buff timing, or interruption/recovery rules during unrelated work.
- When reproducibility matters, identify the RNG owner/seed/persistence; cosmetic randomness must not alter gameplay randomness.

## 5. Godot modification rules

- Follow local naming, indentation, and organization. Do not mass-format unrelated history.
- Prefer typed GDScript when it matches the surrounding code.
- Put designer-tuned values in existing Resources or appropriate `@export` fields; do not expose every internal variable.
- Check related `.tscn` / `.tres` wiring with script changes.
- Renames/moves require checking NodePaths, signals, animation tracks, exported references, and resource references.
- Preserve valid resource UIDs and `.uid` files; never invent UIDs manually.
- `.godot/` and `.codex_runtime/` are generated state, not authored source; both must remain ignored by Git.
- Do not create editor-data folders such as `export_templates/`, `feature_profiles/`, or `text_editor_themes/` in the project root as normal source work. If tooling unexpectedly creates them, report the environment issue before treating them as assets.
- Changes to input actions, collision layers, Autoloads, renderer settings, or other `project.godot` settings require impact review.
- Save tests must use isolated test data and never overwrite user saves.
- New resource/save fields need explicit defaults, invalid/missing-ID behavior, and an old-data compatibility decision.
- Production code must fail clearly when required data is missing; do not silently inject test decks, enemies, or debug data.

## 6. Current known migration exception

`BattleSaveModule.gd` is legacy code scheduled for replacement. Its incompatibility with `EntityData` is known and may produce a Godot 4.7.2 parser/type error.

- Do not fix/refactor it unless the user explicitly requests it or it becomes a hard dependency.
- Do not count this known error as a newly introduced regression.
- Do not claim the entire project has zero parser errors while it remains.
- If another task depends on it, surface the dependency before expanding scope.
- Keep detailed status/replacement plans in `Docs/AI_PROGRESS.md`, not here.

## 7. Validation and delivery

Use these terms precisely:

- **Implemented**: files changed.
- **Static check passed**: inspected/parsed; runtime behavior not observed.
- **Runtime validated**: relevant project/scene executed and target behavior observed.
- **User playtest accepted**: user manually confirmed gameplay/visuals/feel.

Validation expectations:

- Documentation: check facts, paths, and internal consistency.
- Script/scene/resource changes: parse/load when possible and run the narrow relevant path.
- Timeline/card work: verify request conditions, cost, order, time advancement, effect count, and input unlock.
- Exploration work: verify relevant generation/movement, encounter transition, and exploration return.
- Save work: use non-user test data and perform save + reload.
- Lifecycle/interface work: cover normal flow plus relevant failure/cancel/duplicate-entry/cleanup paths.
- Random behavior: record a reproducible seed/condition when supported.

Delivery must briefly state: what changed; what was validated and result; what was not validated; remaining relevant issues; manual Godot steps still required.

## 8. Maintaining AGENTS.md

`AGENTS.md` is a stable operating contract, not a task/history log or automatic preference-learning store.

The agent may **propose** an update after observing a repeated user preference, recurring workflow correction, new stable project constraint, canonical tool/validation path, or user-confirmed long-term architecture rule.

Do not silently turn one-off requests into permanent rules. Do not edit this file merely to match the current task. Before changing an existing rule or adding a behavioral preference, obtain user approval unless the user explicitly requested that the rule become permanent.

### Mandatory change reporting

**Every time this file is modified, clearly tell the user exactly what changed. Never modify it silently.**

The final response for any `AGENTS.md` modification must include an **`AGENTS.md changes`** summary covering:

- rules/sections added;
- rules/sections changed;
- rules/sections removed;
- why each change was made;
- important existing constraints intentionally preserved unchanged.

Do not maintain a running changelog inside this file. Git history plus the explicit user-facing change summary are the change record.
