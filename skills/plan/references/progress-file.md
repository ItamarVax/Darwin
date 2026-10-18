# The Progress File

The `.darwin/darwin-progress.md` file is the central coordination point for
execution. It lives **inside the feature worktree** (created at plan
finalization) and is committed on the feature branch. This file is the single
definition of its schema and of the task Status Vocabulary — `execute`,
`darwin-executor`, `resume`, `reviewing-implementation`,
`finishing-development-branch`, and the session-start hook all use exactly
these values and headings.

## Sections

The progress file MUST contain, in this order:

1. **Overview** — a high-level summary, plus these recorded fields:
   - **Ticket**: `KEY-123` and its URL, or `none` — read by execute (commit trailers), finishing (MR title), and resume
   - **Base**: the branch the feature branched from (the main checkout's current branch at finalization) — read by the evaluation (`git diff <base>...HEAD`), the drift check, and finishing (merge target)
   - **Branch**: the feature branch name (e.g. `feat/<slug>`)
   - **Worktree**: the absolute worktree path
   - **Proposal**: `.darwin/proposal.md` (the approved change proposal, committed next to this file)
   - **Baseline**: the result of the baseline test run at finalization — `pass`, `N failing (<test ids>)`, or `n/a (reduced mode)`
   - **Mode**: `standard` (tests are the contract), `reduced` (no test suite; tasks gated on `Acceptance` checks), or `legacy` (a Darwin 4 plan — set by execute when the v5 fields are missing)
2. **Task Table** — columns `ID`, `Task`, `File(s)`, `Depends on`, `Status` (values from the Status Vocabulary below; every task starts `PENDING`)
3. **Task Details** — one block per task (schema below)
4. **Test lock** — written by execute after wave 0: a table `| path | hash |` of every test-support file and its `git hash-object` hash. Empty until wave 0 completes; absent in reduced mode.
5. **Expected red** — written by execute after wave 0: the locked test IDs that belong to tasks not yet `COMPLETE`, one per line. Execute removes a task's tests from it when the task is committed.
6. **Lessons delivered** — written by execute: `| lesson | tasks |` rows recording which lessons went into which task prompts. Empty when there is no lessons store.
7. **Execution Log** — where the execute orchestrator records each task's outcome, wave decisions, and the evaluation verdict

### Status Vocabulary

| Status | Meaning | Set by |
|--------|---------|--------|
| `PENDING` | Not started | plan (initial value) |
| `IN_PROGRESS` | Dispatched to an executor (or being implemented inline), not yet reported back | execute, just before dispatch |
| `DONE` | Implemented; awaiting the wave gate | execute, from the executor's report |
| `DONE_WITH_CONCERNS` | Implemented, but the executor flagged doubts; awaiting the wave gate | execute, from the executor's report |
| `NEEDS_CONTEXT` | Executor could not start; missing information | execute, from the executor's report |
| `BLOCKED` | Executor could not complete; blocker, impossible spec, or a test defect | execute, from the executor's report |
| `COMPLETE` | Passed the wave gate and committed | execute only, at the per-task commit — never from an executor report |

A test-defect report from an executor is recorded as `BLOCKED` (with "test defect" in the Execution Log) — the table holds only these values, which the session-start hook matches.

**Single writer.** After plan finalization, only the execute orchestrator edits
the progress file. Executors return their log entry in their report; they never
write the file. (Parallel executors writing one shared file would conflict — the
same rule as "parallel tasks must not modify the same files.")

### Behavior deltas heading

Execute writes `### Behavior deltas — applied` in the Execution Log after applying
the proposal's behavior changes (standard and reduced modes). `resume` uses it to
tell whether that step ran.

### Evaluation verdict headings

The end-of-feature evaluation (`reviewing-implementation`) records its verdict in
the Execution Log under exactly one of these headings. `resume` and
`finishing-development-branch` look for them verbatim:

```markdown
### Evaluation — ✅ Approved
### Evaluation — ❌ Escalated
```

## Required Task Detail Fields

Each task detail block must explicitly include:
- **Covers**: the behavior IDs from the proposal this task implements (`EXPORT-7, EXPORT-2`), or `—` for pure plumbing. Task 0 covers every ID whose tests it writes.
- **Tests**: the full test code for the IDs this task covers, with the file each test goes in — or `Written in Task 0` when Task 0 already contains them (the normal case). In reduced mode: `none (reduced mode)`.
- **Exact** (optional): implementation code that must appear verbatim — schemas, migrations, public signatures, config formats, prompt or user-facing copy, tricky algorithms. Everything else the executor writes.
- **Executor**: `subagent` (default) or `inline` — see the plan skill's Executor Field.
- **Tier**: `Fast` or `High` — see the plan skill's Tier Field.
- **Upstream artifacts expected**: artifacts that must exist before the task starts.
- **Shared contracts**: schemas/interfaces/types the task must consume — after Task 0, these are real files on disk.
- **Read-first pointers**: ordered file-pointer list the executor must read before editing.
- **Parallel-Safety Declaration**: statement that tasks in the same execution wave do not write shared files (test files included).
- **Acceptance**: runnable checks — the task's test command first; in reduced mode, the commands or observations that show the task works.

## Task Dependencies

- **Depends on**: comma-separated task IDs that must be COMPLETE before this task can run. Use `—` for no dependencies. In standard mode every task except Task 0 depends on Task 0.
- Tasks with the same dependency set can run **concurrently** in execute mode.
- **Rule**: tasks that may run in parallel must not modify the same files — test files included.
- **Declaration Required**: for each planned parallel wave, include an explicit parallel-safety declaration.

## Task Detail Schema

```markdown
### Task [ID]: [title]
**Files**: `[path/a]`, `[path/b]`

**Covers**: [behavior IDs or `—`]
**Depends on**: [comma-separated task IDs or `—`]
**Parallel-Safety Declaration**: SAFE | REQUIRES_ISOLATION | SERIAL_ONLY
**Tier**: Fast | High
**Executor**: subagent | inline

**Upstream artifacts expected**
- `[exact upstream artifact path or "None"]`

**Read-first pointers**
- `[highest-priority file pointer 1]`

**Shared contracts**
- `[schema/interface/type contract file path]`

**Output artifacts**
- `[exact output file path(s) this task must produce]`

**Tests**
[Full test code in fenced blocks, each with its target file — or "Written in Task 0" — or "none (reduced mode)"]

**Exact** (only when needed)
[Verbatim implementation code in fenced blocks, each with its target file]

**Changes**
1. [what to implement — behavior, signatures, edge cases, error handling — specific enough that no design decision is left]

**Acceptance**
- [runnable check — e.g. `pytest -q tests/export/test_stream.py` passes]
```

## Task 0 Schema

Task 0 exists in standard mode only. Same schema, plus:

```markdown
### Task 0: Skeleton and tests
**Covers**: [every ADDED/MODIFIED ID in the proposal]
**Depends on**: —
**Tier**: High
**Executor**: subagent

**Skeleton**
- `[new file]`: [signatures and types; bodies raise a not-implemented error]

**Test changes**
- ADD `[test file]::[test name]` — [behavior ID] (full code below)
- MODIFY `[test file]::[test name]` — [behavior ID] (full code below)
- DELETE `[test file]::[test name]` — [REMOVED behavior ID]

**Tests**
[Full code for every added and modified test]

**Acceptance**
- Every new and changed test is collected and runs (no collection, import, or syntax errors)
- Tests for ADDED behaviors fail (not-implemented or assertion); tests for MODIFIED behaviors fail on an assertion
```

## Execution Log Schema

```markdown
### Task [ID]: [title]
- **Status**: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED (as reported; the task table, not the log, carries `COMPLETE`)
- **Changes Made**: [brief implementation summary]
- **Files Modified**: `[path/a]`, `[path/b]`
- **Artifacts Produced**: `[exact artifact path(s)]` or `None`
- **Contracts Consumed**: `[contract/spec file path(s)]` or `None`
- **Verification**: per command — `command`, exit code, last lines of output
- **Lessons**: `L-<n>: applied | not relevant` per delivered lesson, or `None`
- **Notes/Risks**: [blockers, caveats, and follow-up items]
```
