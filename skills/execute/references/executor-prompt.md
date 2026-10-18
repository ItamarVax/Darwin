# Executor Dispatch

How the execute orchestrator invokes `darwin-executor`.

## Execution Policy (Stateless by Default)

- **Default**: Start a **fresh** `darwin-executor` subagent for each ready task, and for every re-dispatch (red tests, missing context, fix tasks).
- **No Resume by Default**: Do **not** use `resume` for normal execution.
- **Allowed Resume Exceptions (explicit only)**:
  1. The new task is a tightly-coupled continuation of the immediately previous task on the same implementation thread.
  2. The continuation is not part of a parallel wave.
  3. The orchestrator records a short justification in the execution log.

## How to Invoke

Use the `Task` tool with `subagent_type="darwin-executor"` and the `model` from
[model-selection.md](model-selection.md):

```json
{
  "subagent_type": "darwin-executor",
  "model": "<per model-selection.md>",
  "description": "Implement Task 2: Stream large exports",
  "prompt": "<the prompt contract below>"
}
```

## Required Executor Prompt Contract

Every executor invocation must include:

```text
Task ID and goal:
- Task [N]: [goal]
- Covers: [behavior IDs]
- Mode: standard | reduced | legacy

Read-first pointers (ordered):
- [path 1]
- [path 2]

Shared contracts (schemas/interfaces/types — after Task 0 these are real files):
- [contract path 1]

Dependency context (for each task in this task's `Depends on`):
- Task [M]: [1–3 line summary — what it produced, artifacts, contracts it established]
  (take this from Task M's execution log entry; "None" when the task has no dependencies)

Tests (standard mode):
- Run: [commands.testScoped with {files} replaced by this task's test files]
  (fallback: commands.test)
- Done means: these tests pass and nothing else you touched regresses.

Locked files — do not modify (standard mode, after Task 0):
- [every path in the Test lock table]
  You may add new test files. If a locked test contradicts the behavior or the
  spec, report `BLOCKED: test defect` — never edit it.

Acceptance checks (reduced and legacy mode):
- [the task's Acceptance commands]

Exact code (verbatim, when the task has an Exact block):
- [the Exact blocks from the plan]

Constraints / out-of-scope:
- [constraint]

Deliverables:
- [expected code/doc changes]

Lessons (when any are delivered — see "Delivering lessons" below):
- L-[n]: [summary] — report each as applied | not relevant

Required log entry in your report (do not edit the progress file):
- Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
- Changes Made: ...
- Files Modified: ...
- Artifacts Produced: [exact file paths]
- Contracts Consumed: [exact file paths]
- Verification: per command — command, exit code, last lines of output
- Lessons: L-[n]: applied | not relevant (or None)
- Notes/Risks: ...
```

For **Task 0**, the prompt adds: the Skeleton list, the Test changes list, and
the full test code from the plan — and says the executor writes the skeleton and
tests exactly as given, confirms they are collected and fail as expected, and
does not implement any bodies.

For a **re-dispatch after red tests**, the prompt adds the failing command and
its output from the gate.

## Delivering lessons

When `.darwin/learnings/` exists, select lessons per task (and per fix task):

1. Take the task's `Files` and select active lessons whose `scope` matches them, at most 5, per the `compound` skill's `references/lesson-format.md` ("Selecting Lessons for a Set of Files"). Select using frontmatter only; then read the selected lessons' `## Learning` sections.
2. Put each in the prompt's Lessons block as `L-<n>: <summary>` followed by its `## Learning` text. Omit the block when none match.
3. Record a row in the progress file's `## Lessons delivered` table (`| L-<n> | <task ids> |`) and append a `delivered` event per lesson to this branch's usage log (`.darwin/learnings/usage/<branch-slug>.jsonl`).
4. When the report comes back, append one event per delivered lesson from its `Lessons` line: `applied` or `not-relevant`. A lesson the report omits counts as `not-relevant`.

The orchestrator is the only writer of the usage log during execution. Inline tasks follow the same steps, with the orchestrator judging applied / not relevant itself.

## Bounded-Context Guidance

- Prefer file pointers over pasted code in executor prompts.
- Inject only the highest-value pointer set: shared contracts, task-local files, minimal constraints.
- Avoid broad repository context dumps unless strictly required.
- Paste test code only when it is not yet on disk (Task 0); afterwards point at the test files.

## Handoff Acceptance Checklist

- [ ] Stateless handoff is preserved (fresh subagent by default).
- [ ] Read-first pointers are explicit and consumed before broader exploration.
- [ ] Shared contracts are named explicitly in the prompt/log.
- [ ] The test command and the locked-file list are in the prompt (standard mode).
- [ ] Artifacts are recorded as exact output paths in execution logs.

**Anti-patterns:**
- Passing large prior chat transcripts into executor prompts.
- Using summary-file-only coordination without verifying referenced file pointers on disk.
