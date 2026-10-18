---
name: execute
description: >
  Execute an approved implementation plan using subagents. Use when a plan
  exists in darwin-progress.md and the user is ready to implement.
---

# Execute

> Begin every reply with `[MODE: EXECUTE]`. See `using-darwin` for the full contract.

Implementing exactly what was planned in plan mode.

**Core principle**: follow the plan exactly, and let commands decide "done". The plan is the spec; its tests are the contract. A task is finished when its tests pass at the gate — not when a report says so.

## When This Skill Fires

- User says `/execute`, "let's execute", "start implementing", or similar
- After approving a plan that was written to `.darwin/darwin-progress.md`
- When the user is ready to implement changes

## Constraints

- **Allowed**: Dispatching `darwin-executor` for tasks marked `Executor: subagent`; implementing tasks marked `Executor: inline` directly; running the project's test, lint, and typecheck commands; per-task commits; applying behavior deltas to `.darwin/behaviors/`; running multiple executors in parallel when the progress file lists multiple tasks with satisfied dependencies
- **Forbidden**: Deviating from plan, adding unplanned features, making design decisions not in the plan, editing a locked test to make a gate pass, implementing a `subagent` task inline (a detailed plan is a signal to use the Fast tier, **not** a signal to skip dispatch), committing a task whose gate is red, pushing

## Prerequisites

⚠️ **CRITICAL**: Execute mode requires an approved plan. The progress file `.darwin/darwin-progress.md` must exist with a task table. Its schema and the Status Vocabulary are defined in the `plan` skill's `references/progress-file.md`.

## Execution Principles

- **Plan Adherence**: Implement exactly what was planned, no deviations
- **Tests Decide Done**: The orchestrator re-runs every task's tests itself at the wave gate; executor reports are claims until then
- **Locked Tests**: After Task 0, test-support files are hash-locked; nothing may change what "done" means without the user
- **Isolated Context**: Each subagent task runs in a fresh executor to prevent context drift
- **Progress Tracking**: `.darwin/darwin-progress.md` is the source of truth, and the orchestrator is its **only writer** — executors return their log entries in their reports
- **One Evaluation at the End**: No per-task AI review; the checker and maintainer reviewer run once, after the last wave

## Darwin Config

This section is the single definition of `.darwin/config.json`. Onboarding writes it; every skill, agent, and script that reads it follows this definition.

**Location and loading.** The file is committed to the project. Read it from the worktree root first, then the main checkout root. Every key is optional — a missing file, an unreadable file, or a missing key means the default below.

```json
{
  "profile": "balanced",
  "commands": {
    "test": "pytest -q",
    "testScoped": "pytest -q {files}",
    "lint": "ruff check {files}",
    "typecheck": "pyright",
    "run": "uvicorn app.main:app --port 8000",
    "mutation": "mutmut run --paths-to-mutate {files}",
    "timeoutSec": 600
  },
  "behaviors": { "enabled": true, "strictUncovered": false },
  "learnings": { "promoteAt": 3, "retireAfter": 10 },
  "checker": { "mutationProbes": true, "exerciseApp": "auto" },
  "execute": { "serialWaves": false }
}
```

| Key | Meaning | Default |
|-----|---------|---------|
| `profile` | `economy` \| `balanced` \| `quality` — see Cost Profile below | `balanced` |
| `commands.test` | Runs the full test suite. **Absent = the project has no test setup** | none |
| `commands.testScoped` | Runs only the given tests; `{files}` is replaced with a space-separated file list | falls back to `commands.test` |
| `commands.lint` | Lint command; `{files}` as above | none (`fix-all` detection applies) |
| `commands.typecheck` | Type-check command | none |
| `commands.run` | Starts the application, for the checker to exercise it | none |
| `commands.mutation` | A project mutation-testing tool; `{files}` as above | none (the checker's own probes) |
| `commands.timeoutSec` | Upper bound for any single command above | `600` |
| `behaviors.enabled` | Behavior files and the drift check are active. A no-op while `.darwin/behaviors/` does not exist | `true` |
| `behaviors.strictUncovered` | Changes to code no behavior file covers are errors on every branch, not only on branches with a change proposal | `false` |
| `behaviors.ignore` | Extra path patterns the drift check never treats as product code (`dir/` = any component, `*.ext` = basename, `a/b/*` = full path), added to the built-in list (tests, docs, `*.md`, `.darwin/`, `.cursor/`, `.claude/`, CI files) | `[]` |
| `learnings.promoteAt` | Uses + recurrences at which `compound` proposes turning a lesson into a check | `3` |
| `learnings.retireAfter` | Consecutive "not relevant" deliveries after which a lesson is retired | `10` |
| `checker.mutationProbes` | The checker applies mutation probes to changed lines | `true` (forced off under `economy`) |
| `checker.exerciseApp` | `auto` (when `commands.run` exists and the change is user-facing) \| `always` \| `never` | `auto` (`always` under `quality`) |
| `execute.serialWaves` | Dispatch one task at a time even when several are ready | `false` |

### Cost Profile

State the active profile once at execution start. The profile selects the tier→model mapping and the checker's depth in `reviewing-implementation` (that skill reads the same config).

- **economy** — cheapest viable models; no mutation probes.
- **balanced** (default) — Sonnet-class fast tier, Opus-class high tier; mutation probes on.
- **quality** — same models as balanced; the checker always exercises the app and applies more mutants per changed hunk.


The tier→model mapping, High-tier signals, escalation table, and decision log
format are in [references/model-selection.md](references/model-selection.md) —
the single table shared with `reviewing-implementation`.

## Modes

Read the Overview's `Mode` field at execution start and state it once with the profile:

| Mode | When | What changes |
|------|------|--------------|
| `standard` | The plan has Task 0 and tasks with `Covers`/`Tests` | Full flow below |
| `reduced` | The project has no test suite and the user declined test setup (`Mode: reduced`) | No Task 0, red check, or test lock; the gate runs each task's `Acceptance` commands plus `commands.test` when present; behavior deltas are applied with `Status: observed` |
| `legacy` | A Darwin 4 plan: `Mode: legacy`, or no `Mode` field and task blocks without `Covers`/`Tests` | Same as reduced, and no behavior deltas (there is no proposal). Record `Mode: legacy` in the Overview. If the Overview has no `Baseline`, run `commands.test` once before the first wave and record it, so pre-existing failures are excluded from the gates |

## Execution Flow

The mechanical checks in steps 3–7 are specified in [references/gates.md](references/gates.md). Read it before the first wave.

1. **Load Approved Plan**: Locate the progress file. If `.darwin/darwin-progress.md` exists relative to the current directory, read it. Otherwise read the breadcrumb `.darwin/active-worktree` at the main checkout root — it contains the worktree path — and read `<worktree_path>/.darwin/darwin-progress.md`. Note the `Worktree`, `Branch`, `Base`, `Baseline`, and `Mode` fields from the Overview. Read `.darwin/config.json` (Darwin Config above) and state the active profile and mode.
2. **Enter and Verify Workspace**: The feature worktree was already created at plan finalization (do **not** create a new one). Execution MUST run inside that worktree — otherwise executors will edit the main checkout's copies of source files. Verify the working root and halt if it does not match:
   ```bash
   git rev-parse --show-toplevel
   ```
   If the output does not equal the recorded `Worktree` path, STOP and tell the user:
   > Not inside the feature worktree. Run `cd <worktree_path>` (or reopen the session there), then re-run `/execute`.
   Do not proceed until the working root matches the recorded `Worktree`.
3. **Wave 0 — Task 0** (standard mode): Set Task 0 `IN_PROGRESS` and dispatch it (High). Then run the **red check**, write the **test lock** and the **expected-red** set, and commit Task 0 (gates.md §1–2).
4. **Compute Ready Set**: Tasks with status PENDING whose dependencies are all COMPLETE. With `execute.serialWaves: true`, take one task at a time.
5. **Select Models**: Read each task's `Tier` and `Executor` fields from the plan (evaluate against the High-tier signals only when `Tier` is missing; upgrade-only overrides). Apply the active profile's mapping. Record the decision log.
6. **Dispatch**: Set each ready task's status to `IN_PROGRESS`. Select the task's lessons and record their delivery ([references/executor-prompt.md](references/executor-prompt.md), "Delivering lessons"). Dispatch `subagent` tasks to fresh `darwin-executor`s per that file — in parallel when several are ready. Implement an `inline` task yourself, holding yourself to the same contract: its tests, the locked files, the plan's `Changes`.
7. **Record Reports, then Gate the Wave**: Copy each executor's log entry into the Execution Log, set its status from the report, and append its `applied` / `not-relevant` lesson events to the usage log. When the whole wave has reported, run the **wave gate** (gates.md §3):
   - green → commit the task (`{type}({scope}): Task {N} — {task title}`, plus a `Refs: KEY-123` trailer when the Overview has a `Ticket`), set it `COMPLETE`, remove its tests from `## Expected red`
   - red, `NEEDS_CONTEXT`, `BLOCKED`, or `BLOCKED: test defect` → red handling and escalation (gates.md §4). The task table only ever holds Status Vocabulary values: a test-defect report is recorded as `BLOCKED`, with "test defect" in its log entry
   Executors never run git commands.
8. **Post-Wave Suite** (from wave 1): run the full suite minus the baseline failures and the expected-red set; turn any new failure into a fix task (gates.md §5).
9. **Loop**: Re-read the progress file. Return to step 4 until all tasks are COMPLETE.
10. **Apply Behavior Deltas** (standard and reduced modes; skip if the Execution Log already has `### Behavior deltas — applied`): apply the proposal's behavior changes to `.darwin/behaviors/`, run the drift check, commit, and record the heading (gates.md §6).
11. **Evaluation**: Invoke `reviewing-implementation`. It dispatches `darwin-checker` then `darwin-maintainer-reviewer`, runs any fix loop, and records `### Evaluation — ✅ Approved` (or `### Evaluation — ❌ Escalated`) in the Execution Log — `resume` and `finishing` look for that heading.
12. **Compound Learning**: Invoke the `compound` skill — it captures new lessons from this feature's gates, escalations, and evaluation findings, counts the usage log, and proposes promotions and retirements. If the user declines, proceed to step 13.
13. **Finish**: Invoke `finishing-development-branch` skill.

### Example: 4-Task Plan (0 → 1,2 parallel → 3)

```
Step 2:  Verify cwd == worktree on feat/my-feature; mode standard, profile balanced
Step 3:  Task 0 (High) → skeleton + 6 tests → red check: 6 collected, 6 fail as expected
         Test lock written (9 files), expected red = 6 tests → commit Task 0
Step 4:  Ready = {Task 1, Task 2}
Step 6:  Dispatch Task 1 (Fast) + Task 2 (Fast) in PARALLEL
Step 7:  Gate: Task 1 green → commit; Task 2 red → re-dispatch (fresh, Fast, with output)
         Gate: Task 2 green → commit
Step 8:  Suite: pass (baseline failures excluded)
Step 4:  Ready = {Task 3} (inline)
Step 6:  Implement Task 3 inline → Step 7: gate green → commit
Step 10: Behavior deltas applied → drift check integrity pass → commit
Step 11: Evaluation → ✅ Approved
Step 12: Compound → captured
Step 13: Finishing → user chooses option
```

## Running scripts

Darwin's scripts ship with the plugin, not with the user's project. Run them from the worktree root:

```bash
# Claude Code:
"${CLAUDE_PLUGIN_ROOT}/scripts/behavior-check.sh"

# Cursor: resolve it from this skill's directory — the plugin root is two
# directories above it, e.g. for a local install:
~/.cursor/plugins/local/darwin/scripts/behavior-check.sh
```

(When developing Darwin itself, the plugin root and the project root coincide, so `scripts/behavior-check.sh` works too.)

## Subagent Context Policy

- **Default**: Use stateless subagents (fresh invocation per task and per re-dispatch).
- **Exception**: resume chaining is exception-driven only with justification (see references/executor-prompt.md).
- **Terminology**: Use the same handoff terms: read-first pointers, shared contracts, artifacts, locked files.

## Deviation Handling

If issues arise during execution that require plan changes:
1. Stop execution
2. Return to plan mode to address the issue — and update the proposal when the behavior changes
3. Update the plan (re-lock any changed tests)
4. Resume execution with the updated plan

## Integration

- **Requires**: `.darwin/darwin-progress.md`, `.darwin/proposal.md`, and the feature worktree (all created by the plan skill at finalization); the session must be operating inside that worktree
- **Auto-invokes**: `reviewing-implementation` (end-of-feature evaluation), `compound`, `finishing-development-branch`
- **Uses**: `darwin-executor` agent; `scripts/behavior-check.sh`
- **Defines**: the `.darwin/config.json` contract (Darwin Config above); the tier→model table ([references/model-selection.md](references/model-selection.md))
- **References**: `plan` skill's `references/progress-file.md` (schema, Status Vocabulary), `behaviors` skill's `references/formats.md` (applying deltas), `code-quality-standards.mdc`, `development-commands.mdc`
