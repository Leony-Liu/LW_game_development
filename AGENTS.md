# AGENTS.md

Stable collaboration contract for Web GPT and Desktop Codex.

Keep this file compact, generic, and slow-changing. It defines AI workflow and repository safety, not gameplay design, current project status, detailed architecture, code navigation, or task-specific UI workflows.

Modify this file only when repository-wide AI collaboration rules change.

## Communication

- Report in Simplified Chinese unless explicitly requested otherwise.
- Preserve code identifiers, class names, methods, signals, paths, CLI commands, and exact status strings.
- Keep reports concise and factual; distinguish verified results, historical evidence, and assumptions.
- Never invent unresolved gameplay, content, save, or architecture decisions.

## Canonical Documentation

| Document | Responsibility |
|---|---|
| `/AGENTS.md` | AI collaboration workflow and repository safety |
| `Docs/README.md` | Project overview, current stage, environment, blockers, immediate direction |
| `Docs/CODE_STANDARDS.md` | Required code architecture, implementation, and code-generation rules |
| `Docs/SYSTEM_REGISTRY.md` | Owner-approved System / Subsystem classification and implementation status |
| `Docs/GAME_DESIGN.md` | Approved gameplay rules, player experience, and design decisions |
| `Docs/ARCHITECTURE.md` | Actual system relationships, ownership, contracts, SceneTree, and implementation boundaries |
| `Docs/CODEMAP.md` | Navigation to real source, scene, and resource files |

These documents have separate responsibilities; do not treat them as interchangeable.

### Required reading for implementation tasks

1. Read `Docs/README.md` for current project context.
2. Read `Docs/CODE_STANDARDS.md` before creating or modifying code.
3. Read `Docs/SYSTEM_REGISTRY.md` when working on System / Subsystem boundaries.
4. Read `Docs/CODEMAP.md` to locate likely implementation files.
5. Inspect actual scripts, scenes, Resources, configuration, and affected call sites.
6. Read `Docs/ARCHITECTURE.md` when ownership, interfaces, signals, data flow, or SceneTree relationships need clarification.
7. Read `Docs/GAME_DESIGN.md` when gameplay meaning, player experience, or design decisions need clarification.
8. Use targeted repository search when navigation is insufficient.

For UI tasks, follow `CODE_STANDARDS.md` and inspect current scenes/scripts. Do not rely on unverified historical NodePaths or assume a separate UI workflow document exists. Real workspace files are the source of truth for current implementation.

## Collaboration Model

### Web GPT

- Discusses design and architecture with the user.
- Uses canonical documents and verified implementation reports.
- Plans scoped tasks and prepares instructions for Desktop Codex.
- Identifies decisions requiring user confirmation.
- Does not assume unverified local repository state.

### Desktop Codex

- Reads required documentation and inspects real workspace files.
- Uses the smallest relevant file scope.
- Makes only approved, scoped changes and validates them proportionally.
- Preserves unrelated user work.
- Cleans up current-task process artifacts under this file's rules.
- Reports actual results, deviations, unverified behavior, and unresolved issues.

## Authority and Source of Truth

### Gameplay and player experience

Priority: (1) explicit user decisions in the current task; (2) approved decisions in `Docs/GAME_DESIGN.md`.

If implementation differs from confirmed design, report the gap; do not silently change design assumptions or invent gameplay values. Never resolve `【待设计】`, `TBD`, or equivalent pending decisions without user confirmation.

### Code standards

`Docs/CODE_STANDARDS.md` defines required architecture and implementation rules. If a request conflicts with a mandatory standard, identify the rule, explain the impact, propose the smallest reasonable alternative or exception, and obtain approval before making an architectural exception. Never silently bypass a mandatory standard.

### Architecture

Priority: (1) explicit user decisions in the current task; (2) confirmed rules in `Docs/ARCHITECTURE.md`.

Do not treat proposals, future plans, or `[TARGET]` states as implemented. The architecture document records observed or approved architecture; it does not replace code standards.

### Current implementation

Trust order: (1) real workspace files; (2) current Godot Editor state when relevant; (3) current Runtime state when relevant; (4) documentation summaries.

If documentation conflicts with verified implementation, report the mismatch. Do not change unrelated code to match outdated documentation. Update the responsible document only after implementation is verified. Existing code is not automatically an accepted pattern; inspect it before reuse.

## Stable Development Principles

- Keep design truth separate from implementation truth.
- Follow `CODE_STANDARDS.md` for detailed architecture and implementation rules.
- Prefer minimal, readable, maintainable changes; preserve behavior outside the requested task.
- Respect ownership boundaries; do not create duplicate owners.
- Do not add global systems, Autoloads, frameworks, or architectural layers without a clear requirement.
- Required dependencies and invalid data must fail clearly.
- Handle success, failure, cancellation, and cleanup for lifecycle operations.
- Gameplay systems own gameplay truth. UI reflects state and submits player intent; it does not decide gameplay outcomes.
- Gameplay must not depend on a specific animation, visual effect, or audio asset.
- Keep generic infrastructure separate from gameplay-specific logic.
- Do not implement deferred functionality or resolve pending design decisions without authorization.
- Verify only as deeply as required to prove the task. Never claim runtime behavior from static inspection alone.

## Dependency and Communication Direction

Follow `CODE_STANDARDS.md`. Repository defaults:

- Prefer **downward calls and upward notifications**: coordinators call modules they own; lower-level modules emit signals for events/state changes.
- "Higher/lower level" means architectural responsibility and state ownership, not literal SceneTree position. Parentage defines containment/lifecycle, not automatically architectural ownership.
- Give every dependency a clear direction and reason. Avoid circular dependencies and lower-level callbacks into coordinators.
- External systems communicate only through a System's public Entry script. Do not access internal Managers through NodePaths, properties, or direct references.
- Signals are notifications, not hidden request/response calls. If a result is required, use an explicit method or result contract.
- Do not mechanically replace methods with signals or vice versa.
- The owner of an event/state change defines and emits its signal. An emitter should not require a particular listener or wait for acknowledgement unless an explicit contract requires it.
- UI must not query multiple gameplay systems to reconstruct authoritative state; the responsible coordinator provides display data or a presentation interface.
- Mark dependencies required or optional. Missing required dependencies fail clearly; optional dependencies may disable only the affected feature through an explicit fallback.
- Do not add an Autoload, global event bus, or logging infrastructure to bypass dependency rules.

## Logging

For new logs in important workflows, use `[ScriptName] Description`:

```gdscript
print("[WorldManager] Map initialization started")
push_warning("[RoomSet] Invalid entries were skipped")
push_error("[BattleManager] Initialization failed: required dependency is missing")
```

- Use `print()` for meaningful milestones/state transitions, not per-frame activity.
- Log success only after the operation succeeds.
- Use `push_warning()` for recoverable anomalies with a safe fallback.
- Use `push_error()` for failures that prevent safe completion.
- Logs do not propagate outcomes; return a result or emit a documented completion/failure signal when the caller needs to act.
- Do not bulk-reformat existing logs unless required.

## GDScript Comments

When creating or substantially modifying `.gd` scripts:

- Write short comments in Simplified Chinese; keep identifiers and Godot API names unchanged.
- Add a 2–3 line script header describing purpose and responsibility.
- Add one short method comment describing purpose and key mechanism.
- Comment inside methods only for important branches, state changes, cross-system interactions, and non-obvious decisions.
- Do not write tutorials, large modification notes, or line-by-line code translations.

## Implementation Approval Gate

New gameplay features, new system capabilities, and significant implementation changes MUST follow the four stages below. Architecture, data-model, persistence, and public-interface changes are always significant.

1. **Analysis (read-only):** Web GPT/Desktop Codex may inspect scripts/scenes, search existing implementations, investigate feasibility, identify ownership and missing decisions, and compare approaches. Production implementation changes are not allowed before approval.
2. **Concrete proposal:** Before coding, Desktop Codex MUST describe:
   - Feature behavior, player experience, and acceptance criteria.
   - Owning System / Subsystem / Component.
   - Exact existing files to modify and new files to create, with each script's responsibility.
   - Classes, methods, signals, and important properties to add/modify.
   - Implementation mechanisms/algorithms and why they are appropriate.
   - Request/event/result flow, data ownership, mutation authority, and object lifecycle.
   - Scene, Resource, NodePath, and Autoload changes.
   - Save-data, persistence, and compatibility impact.
   - Failure, cancellation, retry, and cleanup behavior.
   - Validation/regression plan, risks, constraints, and alternatives.

   Explain why each new script cannot reasonably be handled by an existing script/component. For every new or materially changed method, state its responsibility, inputs, outputs, caller/owner, and interaction with other methods. A high-level feature description alone is insufficient.
3. **Explicit owner approval:** Implementation MUST wait for the project owner's approval of the concrete proposal. Approval covers only its stated scope and approach. Unapproved script additions/removals/replacements, new Managers/Components/Systems/Autoloads, public-interface or ownership changes, material mechanism changes, additional scene/Resource changes, persistence/schema changes, or scope expansion require renewed approval. If blocked, stop the affected work, explain the obstacle and alternatives/impacts, request approval, and resume only after approval.
4. **Implementation review:** Inspect the final diff and compare it with the approved proposal. Report every modified/created/removed/renamed file; every added/modified class, method, signal, and important property; actual mechanisms/data flow; approved or unapproved deviations; validation commands/results; and remaining risks/unverified behavior. Do not claim exact compliance without final-diff inspection.

A narrowly scoped bug fix explicitly requested by the owner may proceed directly if it stays within the requested scope. New features, material architecture changes, expanded file scope, save-format changes, or authoritative ownership changes still require approval. Do not bundle unrelated cleanup into a bug fix. Approval of one task does not authorize subsequent work.

This gate concerns implementation, not read-only investigation. Approval for historical-file cleanup is separate.

## Before Editing

- Inspect `git status`; treat existing uncommitted changes as intentional.
- Record the initial state of directories where task-generated files may be written, so pre-existing files can be distinguished.
- Inspect relevant source, scenes, Resources, configuration, and call sites.
- Identify the smallest required file set and check whether the behavior already exists.
- Preserve unrelated work; do not perform unrelated refactors, broad renames, or legacy repairs.
- Do not add unnecessary dependencies, Autoloads, or global managers.
- Before changing scripts/scenes/Resources, check affected NodePaths, signals, exported references, animation tracks, Resource references, ownership, and initialization order.
- Never manually invent Godot UIDs.

## Godot Validation

Canonical CLI entry point:

```powershell
.\tools\godot_cli.ps1 <Godot args>
```

Use the smallest validation that proves the task: (1) source inspection; (2) targeted Godot CLI validation; (3) targeted scene execution or temporary probe when required; (4) Editor MCP when editor state matters; (5) Runtime MCP when live behavior must be observed.

Prefer targeted runtime checks over broad SceneTree dumps. Put temporary probes/task-specific outputs in `.ai/tmp/<task-id>/` where possible. If a tool requires `.ai/runtime/` or another fixed location, record the exact task-created paths and clean them after validation and process shutdown.

Save validation must use isolated test data and must not overwrite user saves.

For Codex-launched Godot processes: track process IDs; ensure test processes exit after success, failure, or timeout; verify related MCP ports are released; never terminate the user's Godot Editor, running game, or unrelated processes; report anything that could not be cleaned up.

## Repository and Git Safety

- Never discard, overwrite, revert, or normalize unrelated user changes.
- Do not create commits, branches, tags, merges, rebases, or pushes unless explicitly requested.
- Do not modify `.gitignore`, `.gitattributes`, repository tooling, or shared infrastructure unless required.
- Never use broad cleanup commands such as `git clean`.
- Avoid wildcard/directory-wide deletion when exact paths can be identified.

## Codex Process Artifacts and Cleanup

Use `.ai/` for Codex-specific process artifacts; read `.ai/README.md` for its organization.

- `.ai/scripts/`: maintained process helpers.
- `.ai/generated/`: generated snapshots only when explicitly approved as durable project artifacts; other current-task outputs remain disposable.
- `.ai/runtime/`: automation state and runtime-related data.
- `.ai/tmp/`: disposable task-scoped probes and intermediate files.

Keep project tools, canonical documentation, gameplay code, scenes, Resources, and user-maintained files in their established locations.

### Deliverables versus process artifacts

**Formal deliverables** include approved source code, scenes, Resources, and canonical documentation updates. Reports and attachments are persistent project deliverables only when the project owner explicitly requests or approves their persistent retention; a request to perform an investigation or write a report alone does not authorize permanent retention.

**Process artifacts** are files created only to perform, inspect, debug, compare, test, or validate a task. Examples include temporary screenshots/confirmation images, Contact Sheets, previews, probe logs, console captures, test output, intermediate JSON/CSV/TXT/Markdown, temporary helper scripts, scratch files, working copies, temporary backups, patches, exports, downloaded references, inventories, hash manifests, and task-only folders.

A file is not temporary merely because of its extension or name. Determine whether it is a formal deliverable, a required project/runtime file, or a temporary task aid.

Architecture investigations, code inspections/audits, design and implementation analyses, migration proposals, verification/test reports, runtime investigations, baseline reports, inventories, hash comparisons, task completion summaries, temporary Markdown, and other task-only analysis documents are **process artifacts by default**, even if previously generated as formal task outputs. A Markdown extension, formal title, report structure, technical detail, or usefulness for future reference does not make them permanent project documents.

### Mandatory current-task cleanup

**All process artifacts created by the current task MUST be deleted after their purpose is complete and before the task is reported as finished.** This is pre-authorized for files confirmed to have been created by the current task; no separate deletion approval is required.

- Prefer a dedicated `.ai/tmp/<task-id>/` directory and record exact paths for outputs created elsewhere.
- Keep process artifacts only until implementation, validation, and review are complete.
- After validation and shutdown of Codex-launched processes, delete all current-task process artifacts and the task-specific temporary directory.
- Check for task-created outputs outside the expected temporary directory, including tool-generated files in `.ai/runtime/`.
- Preserve formal deliverables and pre-existing files.
- Do not delete shared runtime state, active process data, Godot user data, import data, or other operational files unless they are confirmed task-scoped disposable outputs.
- Do not use wildcards or broad cleanup commands. Delete only exact paths known to have been created by the current task.
- If origin, ownership, or active use is uncertain, preserve the file and report it.
- If cleanup fails, list the exact path and reason; do not claim cleanup is complete.

Do not retain process artifacts merely because they may be useful someday. Extract necessary results, evidence, paths, risks, and recommendations into the final Codex response or an explicitly approved persistent deliverable, then remove temporary reports and working materials before completion.

### Explicit report retention authorization

Audits and investigations follow the default process-artifact cleanup policy; requesting an audit does not automatically authorize retention of its final report.

- Retain a report only when the owner explicitly requests a permanent project report, designates it as a persistent project deliverable, or approves its exact path for long-term retention. If it is needed for a later task, obtain explicit retention approval.
- An AI-generated task instruction or previous Codex task does not override the owner's latest retention decision.
- If retention intent is unclear, deliver sufficiently detailed findings in the final response and remove the temporary report. Do not leave an extra Markdown report in `.ai/runtime/` merely to demonstrate completion.
- For reports generated for analysis, review, decision-making, or implementation planning, complete the investigation, extract conclusions/evidence for the final response, and delete the report and intermediate materials before completion.
- Transfer only approved, durable project decisions into their responsible canonical documents when that update is authorized. Never copy unapproved proposals into architecture documentation as established facts.
- Only explicitly approved persistent reports/attachments may remain. Temporary screenshots, Contact Sheets, logs, inventories, hash manifests, intermediate analyses, and helper scripts must still be deleted.

The final response must include enough evidence, exact source paths, findings, risks, and recommendations to support the owner's decision without requiring a persistent process report.

### Pre-existing and historical files

Current-task cleanup applies only to artifacts confirmed to have been created by the current task. It does NOT authorize deletion, movement, renaming, or archiving of pre-existing files.

The default report policy is not authorization to remove existing reports or historical evidence. Distinguish current-task artifacts, pre-existing historical files, and exact paths separately approved for deletion; only the latter may be removed from historical materials.

- Historical files may be changed only after the owner approves the exact paths. Approval of a task, folder, or general cleanup objective does not approve every contained file.
- Inspect contents, references, current use, and historical value before proposing changes.
- Preserve active runtime state, user data, historical verification evidence, and uncertain files.
- Age, task completion, filename, temporary-looking location, or lack of textual references alone does not prove a file is obsolete.
- Recheck approved candidates immediately before acting. If contents, references, or activity changed, request renewed approval.
- Change only exact approved paths. Removing an empty historical directory also requires approval.
- Do not perform broad historical `.ai/` cleanup as an unrelated addition to an ordinary feature task. Review historical materials when explicitly requested or included in the approved scope.

## Mandatory Task-End Cleanup Review

Before reporting a task complete, verify:

1. Approved implementation deliverables and explicitly authorized persistent reports are saved in their proper locations; task-only analysis/report findings are delivered in the final response.
2. Implementation, validation, and review are complete.
3. Codex-launched processes have exited and related ports are released where applicable.
4. All current-task process artifacts have been deleted.
5. No unapproved current-task investigation/audit/verification report, proposal, temporary Markdown, screenshot, probe, log, intermediate export, scratch script, or task-only directory remains.
6. Pre-existing files, user data, unrelated Git changes, and historical materials remain intact unless explicitly approved otherwise.
7. Any cleanup failure or uncertain file is reported by exact path and reason.

The completion report must distinguish formal deliverables retained, current-task process artifacts deleted, any undeleted process artifacts, pre-existing historical files left untouched, and historical cleanup still awaiting approval.

A task is not cleanup-complete while known current-task process artifacts remain, unless the owner explicitly approves persistent retention of the exact artifact.

## Documentation Maintenance

Update only the document responsible for the changed information:

- `Docs/README.md`: project stage, environment, blockers, immediate direction, verification boundaries.
- `Docs/GAME_DESIGN.md`: user-approved gameplay decisions, scope, and design rules.
- `Docs/ARCHITECTURE.md`: system ownership, architecture relationships, contracts, SceneTree structure, and cross-system data flow.
- `Docs/CODEMAP.md`: important file paths, entry points, and navigation guidance.

Do not maintain deprecated parallel documentation. Do not create a separate workflow document for a narrow task unless it has a durable, distinct responsibility and the owner approves it.

## Completion Report

Report in Simplified Chinese. Complete all required inspection, implementation, verification, and cleanup; concise reporting must not reduce the work performed.

Keep the report brief, normally 5–8 bullets, and include:

- Outcome and key changes.
- Every file modified, created, removed, or renamed.
- Validation performed and actual results.
- Godot test-process cleanup status.
- Current-task process-artifact cleanup status.
- Formal deliverables retained.
- Investigation, analysis, verification, and proposal findings with necessary evidence/source paths, risks, and recommendations directly in the final response when persistent report retention was not explicitly authorized. Do not generate a separate permanent completion report by default.
- Remaining issues, unverified behavior, and unresolved owner decisions.
- Deviations from the approved implementation proposal.

Avoid long audits or diagrams unless requested or needed to explain a blocker. Never claim more than was actually inspected, executed, verified, or cleaned up.
