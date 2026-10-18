---
name: resume
description: >
  Resume an interrupted execution from .darwin/darwin-progress.md. Parses task
  states, detects the interruption point, reconstructs context from the execution
  log, and re-enters EXECUTE mode. Use when the user says "/resume", "resume
  execution", or when the session-start hook suggests resuming.
---

# Resume

Pick up an interrupted execution where it left off. Reads the progress file,
identifies which tasks are done and which remain, and transitions back into
EXECUTE mode without re-planning.

**Core principle**: reconstruct context from artifacts on disk, not from memory.

## When This Skill Fires

- User says `/resume` or "resume execution"
- Suggested by the session-start hook when `.darwin/darwin-progress.md` has incomplete tasks

## Prerequisites

This skill requires an active plan's `darwin-progress.md` to exist. Because the plan is created inside a feature worktree, locate it as follows:

1. If `.darwin/darwin-progress.md` exists relative to the current directory, use it — the session is already inside the worktree.
2. Otherwise, read the breadcrumb at the main checkout root: `.darwin/active-worktree`. It contains the worktree path. Use `<worktree_path>/.darwin/darwin-progress.md`, and tell the user to continue inside that worktree (`cd <worktree_path>`).

If neither is found:

```
No active execution to resume. No .darwin/darwin-progress.md found.
Use /plan to create an implementation plan first.
```

## Process

### Step 1 — Read Progress File

Read `.darwin/darwin-progress.md` in full. Extract:
- **Overview**: the high-level goal, plus the `Mode`, `Baseline`, and `Ticket` fields
- **Task table**: all task IDs, titles, files, dependencies, and statuses
- **Test lock** and **Expected red**: the locked test files with their hashes, and the locked tests still expected to fail
- **Execution log**: previous wave decisions, model selections, concerns, blockers

### Step 1b — Detect Mode

The progress file's schema (Overview fields, Test lock, Status Vocabulary, evaluation
verdict headings) is defined once in the `plan` skill's `references/progress-file.md`.

| Mode | How to detect | What it means on resume |
|------|---------------|-------------------------|
| `standard` | Overview `Mode: standard` | Tests are the contract. Re-verify the Test lock (Step 4b) before resuming |
| `reduced` | Overview `Mode: reduced` | No test lock. Tasks are gated on their `Acceptance` checks |
| `legacy` | Overview `Mode: legacy`, or no `Mode` field and task blocks without the `Covers`/`Tests` fields (a Darwin 4 plan) — the same rule as the execute skill's Modes table | No wave 0, test lock, or behavior deltas. Gate = each task's `Acceptance` checks plus the clean-tree check; the post-wave suite runs `commands.test` when present |

Report the detected mode in the status summary (Step 5).

### Step 2 — Classify Task States

Sort tasks into buckets:

Statuses are defined once in the `plan` skill's Status Vocabulary.

| Status | Meaning |
|--------|---------|
| COMPLETE | Passed the wave gate and committed — skip these |
| IN_PROGRESS | Dispatched when the session ended — needs re-dispatch |
| DONE | Implemented, not yet gated or committed — run the wave gate |
| DONE_WITH_CONCERNS | Implemented, not yet gated — show the concerns, then run the wave gate |
| NEEDS_CONTEXT | Executor lacked information — needs context before re-dispatch |
| PENDING | Not started yet — will be dispatched when dependencies are met |
| BLOCKED | Hit a blocker or a test defect (`BLOCKED: test defect`) — needs user input before proceeding |

### Step 3 — Detect Interruption Point

The interruption point is determined by:
1. If any task is IN_PROGRESS, DONE, or DONE_WITH_CONCERNS, that's the interruption point
2. Otherwise, the first PENDING task after the last COMPLETE task is the resume point
3. If all tasks are COMPLETE, there's nothing to resume (see edge cases)

### Step 4 — Verify Git State

Check the current git branch and working tree:

```bash
git branch --show-current
git status --porcelain
```

- If the branch doesn't match the execution context (e.g., progress file references a feature branch but you're on main), the session is in the wrong working directory — the feature branch is checked out **in the worktree**, so `git checkout` from the main checkout will fail with "already checked out". Compare `git rev-parse --show-toplevel` against the plan's `Worktree` field and warn:
  ```
  Warning: Progress file was created on branch `feat/my-feature` but you're on `main`.
  The feature branch is checked out in the worktree. Move there before resuming:
  > cd <worktree_path>
  ```
- If there are uncommitted changes, warn the user and ask whether to stash or commit them first. Exception: uncommitted changes in the files of DONE / DONE_WITH_CONCERNS tasks are expected — that is the work awaiting the wave gate. Name them in the summary rather than asking to stash them.

### Step 4b — Re-Verify the Test Lock (standard mode only)

Skip this step in reduced and legacy mode, and in standard mode when the Test lock
table is still empty (wave 0 never completed — Task 0 is the resume point).

For every row of the Test lock table, re-hash the file and compare:

```bash
git hash-object <path>
```

- **All hashes match** → note "Test lock verified" in the summary.
- **Any mismatch or missing file** → do not resume silently. Report each one to the user:
  ```
  Test lock mismatch:
  - tests/export/test_stream.py — locked <hash>, now <hash>
  Locked tests changed since wave 0. Restore them (git checkout -- <path>),
  or confirm the change was intended and re-lock before continuing.
  ```
  Wait for the user's decision. Never re-lock on your own.

### Step 5 — Present Status Summary

```
Session resumed from .darwin/darwin-progress.md

Goal: [overview from progress file]
Ticket: [KEY-123 from the Overview, or "none"]

Mode: [standard | reduced | legacy]
Test lock: [verified | N mismatches (listed above) | not yet recorded | n/a]

Completed: Tasks [list] (committed)
In progress: Task [N] (interrupted — will re-dispatch)
Pending: Tasks [list]
Awaiting wave gate: [DONE / DONE_WITH_CONCERNS tasks, or "None"]
Needs context / blocked: [list or "None"]

Last wave: Wave [N] — [brief description]
[Any concerns or blockers from execution log]

Ready to continue from Task [N]. Proceed?
```

Wait for user confirmation before proceeding.

### Step 6 — Re-Enter EXECUTE Mode

After user confirms:
1. Set mode to EXECUTE
2. Resume the execution flow from Step 4 (Compute Ready Set) — or Step 3 (Wave 0) when Task 0 is not yet COMPLETE — in the execute skill
3. IN_PROGRESS tasks are re-dispatched (they may have partial work — the executor reads the current file state)
4. COMPLETE tasks are skipped — their commits already exist
5. DONE and DONE_WITH_CONCERNS tasks resume at the **wave gate** (the execute skill's gate: re-run each task's tests — or its `Acceptance` checks in reduced/legacy mode — verify the test lock, check the clean tree, then commit) before anything is re-dispatched
6. BLOCKED and NEEDS_CONTEXT tasks are surfaced to the user before dispatching other tasks

## Edge Cases

| Situation | Behavior |
|-----------|----------|
| No `.darwin/darwin-progress.md` | Report "No active execution to resume", suggest `/plan` |
| All tasks COMPLETE | Report "All tasks from this plan are complete." Then, in order: (1) standard/reduced mode without `### Behavior deltas — applied` in the log → resume at the execute skill's step 10 (apply deltas); (2) no `### Evaluation —` heading → suggest the end-of-feature evaluation (`reviewing-implementation`); (3) `### Evaluation — ✅ Approved`, or a Darwin 4 `### Final Review — ✅ Review approved` → suggest `finishing-development-branch`; (4) `### Evaluation — ❌ Escalated` → show the escalation and ask the user how to proceed. |
| Fix tasks `F<n>` pending | The session ended inside the evaluation's fix loop. Resume in `reviewing-implementation` Step 3 (fix loop) — not at execute step 4 — so the behavior deltas are not applied again. |
| Test lock mismatch (standard mode) | Report each mismatched file (Step 4b). Do not resume until the user restores the files or confirms a re-lock. |
| Legacy progress file (no `Mode`, `Covers`, or `Tests`) | Resume in legacy mode. Do not invent a Test lock or Task 0. |
| A task is BLOCKED | Show the blocker details from the execution log. Ask: "How would you like to handle this? (a) Provide guidance and re-dispatch, (b) Skip this task, (c) Return to /plan to revise" |
| Progress file is malformed | Report: "Progress file appears corrupted — could not parse task table." Offer to read the original plan file if referenced. |
| Wrong git branch | Warn and direct the user to `cd <worktree_path>` (the branch lives in the worktree). Do not proceed until confirmed. |
| Uncommitted changes | Warn and ask: "Stash changes, commit them, or abort resume?" |

## Red Flags

| Red flag | Prevention |
|----------|------------|
| Resuming without reading the full progress file | Always read the complete file in Step 1 |
| Skipping git state verification | Always check branch and working tree in Step 4 |
| Resuming past a changed locked test | Always re-hash the Test lock in standard mode (Step 4b) |
| Committing DONE tasks without gating | DONE means "awaiting the wave gate" — run the gate first |
| Auto-proceeding without user confirmation | Always present summary and wait in Step 5 |
| Re-dispatching COMPLETE tasks | Filter by status — only dispatch IN_PROGRESS, NEEDS_CONTEXT (with context), and PENDING |
| Ignoring BLOCKED tasks | Surface blockers before dispatching other tasks |

## Integration

- **Suggested by**: session-start hook (when progress file has incomplete tasks)
- **Reads**: `.darwin/darwin-progress.md`
- **Transitions to**: EXECUTE mode (execute Step 3 or 4 onward)
- **Works with**: `darwin-executor` (re-dispatches incomplete tasks), `reviewing-implementation` (the end-of-feature evaluation, when every task is COMPLETE)
