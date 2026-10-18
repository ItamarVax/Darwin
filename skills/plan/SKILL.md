---
name: plan
description: >
  Create detailed implementation plans with task breakdown. Use when the user
  has chosen an approach and needs a step-by-step plan before execution.
---

# Plan

> Begin every reply with `[MODE: PLAN]`. See `using-darwin` for the full contract.

Creating detailed technical specifications and implementation plans.

**Core principle**: tests are the contract. Plan so execution is mechanical — a
skeleton fixes the shapes, full test code defines "done" for every task, and
exact implementation code appears only where the exact text is the point. Leave
the executor no design decisions, but let it write the code.

## When This Skill Fires

- User says `/plan`, "let's plan", "create a plan", or similar
- User says `/plan PROJ-123` (or passes a Jira URL) — fetch the ticket per the `research` skill's Ticket Entry Point when the research file has no `## Ticket`
- After the change proposal is approved in innovate mode
- When a comprehensive implementation plan is needed before changes
- When the user wants a step-by-step roadmap for implementation

## Constraints

- **Allowed**: Creating plans, writing and revising the change proposal, asking clarifying questions, mapping scope, reading code
- **Forbidden**: Making any code changes until plan is approved

## Planning Process

1. **Consult Prior Learnings**: If the research file has a `## Lessons` section, use it. Otherwise, if `.darwin/learnings/` exists, read the frontmatter of its lesson files and select the active lessons whose `scope` matches the change's files, per the `compound` skill's `references/lesson-format.md`. Surface them: "Previous learnings that may apply: [L-<n>: one-line summary, ...]". Let them shape the plan (a test for a known trap, an `Exact` block where a mistake recurred). Execute delivers them to executors itself — don't paste them into task blocks.
2. **Load the Change Proposal** (the design spec): `.darwin/proposal.md` in the main checkout is the source of truth for *what* to build — the approach, what is out of scope, and the behavior changes with their IDs. Its format is defined in the `behaviors` skill (`references/formats.md`).
   - **Present** → read it. Every `ADDED`/`MODIFIED` ID must end up covered by a task (step 9).
   - **Absent** (innovate was skipped because there was one obvious approach) → write it now from the conversation and the research file, per the format, and get the user's approval before continuing. If you cannot identify the approach (fresh session, compacted context), stop and ask the user to restate it.
3. **Check the Test Setup**: Read `commands.test` from `.darwin/config.json` (see the `execute` skill's Darwin Config section).
   - **Present** → standard mode: Task 0 plus tests in every task.
   - **Absent** → stop before drafting tasks and offer onboarding's test-setup step (the `onboarding` skill, `references/test-setup.md`). If the user accepts, run that step, then **commit its files on the current branch** (with the user's go-ahead) as `chore(test): set up test suite` — the feature worktree is cut from `HEAD`, so uncommitted setup would be missing there. Set the proposal's line to `Test suite: present` and continue in standard mode. If the user declines, continue in **reduced mode**: no Task 0, each task keeps runnable `Acceptance` checks, and the proposal gets the line `Test suite: none (reduced mode)`.
4. **Consult Research Output** (codebase facts only): If `.cursor/darwin-research.md` exists, read it as the authoritative source for *facts about the existing code* — what exists, where, with what signatures. Research does NOT decide the design; the proposal does. Map its sections to the plan as follows:
   - `## Ticket` → the Overview's `Ticket` field; each acceptance criterion must map to at least one behavior ID in the proposal
   - `## Summary` → context for the plan Overview
   - `## Behaviors` → the behavior files and IDs the change touches; `MODIFIED`/`REMOVED` IDs must exist there
   - `## Draft behavior changes` → already folded into the proposal; check nothing was dropped
   - `## Key files` → task `Files` and `Read-first pointers` (use the line ranges verbatim)
   - `## Signatures & contracts` → task `Shared contracts`, the Task 0 skeleton, and `Exact` blocks
   - `## Data flow` → ordering of tasks and dependency edges
   - `## Constraints & invariants` → test cases and `Acceptance` criteria
   - `## Integration points` → where new code plugs in, named in `Changes`
   - `## Test setup & coverage` → where tests go, which fixtures to reuse, which existing tests change; `N/A` flags a gap
   - `## Open questions` → the gap list for step 6 below
5. **Deep Reflection**: Combine the proposal (step 2) with the codebase facts (step 4) to determine the changes needed. The proposal dictates the design; research dictates how it slots into existing code.
6. **Code Analysis** (identify gaps, don't fill them yet): If `.cursor/darwin-research.md` is present, treat its `## Signatures & contracts`, `## Data flow`, `## Constraints & invariants`, `## Integration points`, and `## Test setup & coverage` sections as authoritative for codebase facts — do not re-read source for content those sections already cover. Build a gap list of areas where research is insufficient:
   (a) areas explicitly flagged in `## Open questions`,
   (b) sections marked `N/A` that turn out to be plan-relevant,
   (c) topics outside the original research scope, or
   (d) details the proposal (step 2) introduces that research didn't anticipate — new files, new contracts, new integration points.
   If the research file is absent, treat the whole codebase map as a single gap.
7. **Fill Gaps via Refinement Dispatch** (preserves the cost split): If the gap list from step 6 is non-empty, dispatch `darwin-researcher` once with the refinement flag and a single consolidated topic naming all gaps. Use the same model-selection mapping as the research skill: on Claude Code pass `model: "sonnet"`; on Cursor omit the `model` parameter. After the subagent returns, re-read `.cursor/darwin-research.md` — the extended sections are now authoritative for those gaps. Do NOT re-read source files in the main session to fill gaps; the subagent is the cost-control mechanism, and bypassing it defeats the purpose of the research/plan split.
8. **Clarifying Questions**: Ask targeted questions to refine the plan. One question at a time, multiple-choice when possible.
9. **Comprehensive Planning**: Draft Task 0 and the tasks per "Tests and Exact Code" below, using the schema in [references/progress-file.md](references/progress-file.md).
10. **Plan Self-Review**: Before presenting, scan the plan for quality issues (see below).
11. **Finalize — Create Workspace and Land the Plan on its Branch**: Once the plan is approved, set up the isolated workspace and commit the plan onto the feature branch:
    1. **Derive the branch name** from the plan's Overview title: lowercase it, replace runs of non-alphanumeric characters with single hyphens, trim, and prefix with `feat/` (e.g. "Move worktree creation to plan phase" → `feat/move-worktree-creation-to-plan-phase`). When the plan has a `Ticket`, put the key (uppercase, as Jira writes it) before the slug, and use `fix/` for a Bug ticket: `feat/PROJ-123-add-export-endpoint`, `fix/PROJ-456-null-date-crash`. Present the derived name and let the user override it before continuing.
    2. **Persist the plan first** — resolve `main_root="$(git rev-parse --show-toplevel)"`, record `Base` as its current branch (`git -C "$main_root" branch --show-current`), and write the plan to `$main_root/.darwin/darwin-progress.md` (NOT into `.cursor/`) *before* creating the worktree, so a failure or crash during workspace setup cannot lose the approved plan. Record the branch name, `Proposal`, and `Mode` in the Overview per the schema (the worktree path and baseline are added below).
    3. **Make sure Darwin's project state is committed.** The worktree is cut from `HEAD`, and execute, the drift check, and the checker read `.darwin/config.json` and `.darwin/behaviors/` from the worktree. If either has uncommitted changes in the main checkout (`git status --porcelain .darwin/config.json .darwin/behaviors/`), show them and ask the user to commit them (or let you commit them as `chore(darwin): project config and behaviors`) before continuing.
    4. **Create the worktree** by invoking the `using-git-worktrees` skill with the chosen branch name. That skill runs directory selection and the `.gitignore` safety check, then `git worktree add`, then project setup. Capture the resulting worktree path as an absolute path (`worktree_path="$(cd <worktree_path> && pwd)"`). If worktree creation fails, stop and report — the plan is safe on disk from step 2.
    5. **Move the plan and the proposal into the worktree** and record the `Worktree` field in the Overview:
       ```bash
       mkdir -p "<worktree_path>/.darwin"
       mv "$main_root/.darwin/darwin-progress.md" "<worktree_path>/.darwin/darwin-progress.md"
       mv "$main_root/.darwin/proposal.md" "<worktree_path>/.darwin/proposal.md"
       ```
    6. **Run the baseline** (standard mode only): run `commands.test` inside the worktree and record the result in the Overview's `Baseline` field — `pass`, or `N failing (<test ids>)`. When tests fail, show them and ask the user: proceed with these recorded as known failures (execute excludes them from every later gate), or stop and fix the baseline first. In reduced mode, record `Baseline: n/a (reduced mode)`.
    7. **Link `.cursor/` into the worktree** so executors and reviewers see the project's rules (`code-quality-standards.mdc`, `project-context.mdc`). Only when the main checkout has a `.cursor/` directory and the worktree does not (i.e., it isn't git-tracked); never clobber an existing path:
       ```bash
       if [ -d "$main_root/.cursor" ] && [ ! -e "<worktree_path>/.cursor" ]; then
         ln -s "$main_root/.cursor" "<worktree_path>/.cursor"
       fi
       ```
    8. **Commit the plan and the proposal on the branch** (the executor never commits; this commit is the plan's, made by the orchestrator):
       ```bash
       git -C <worktree_path> add .darwin/darwin-progress.md .darwin/proposal.md
       git -C <worktree_path> commit -m "chore(plan): add implementation plan for <title>"
       ```
    9. **Drop the resume breadcrumb** at the main checkout root so a session started outside the worktree can find the active plan. Make sure it is git-ignored — via the clone-local `info/exclude` file, so the main checkout's tracked files stay untouched:
       ```bash
       mkdir -p "$main_root/.darwin"
       printf '%s\n' "<worktree_path>" > "$main_root/.darwin/active-worktree"
       if ! git -C "$main_root" check-ignore -q .darwin/active-worktree; then
         echo ".darwin/active-worktree" >> "$(git -C "$main_root" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
       fi
       ```

## The Progress File

`.darwin/darwin-progress.md` is the central coordination point for execution.
Its full schema — Overview fields, task table, task detail and Task 0 schemas,
the `Test lock`, `Expected red`, and `Lessons delivered` sections, the execution
log schema, the evaluation verdict headings, and the **Status Vocabulary** — is
defined once in [references/progress-file.md](references/progress-file.md).
Read it before drafting.

## Task 0 — Skeleton and Tests

In standard mode the plan always starts with Task 0, Tier `High`, which every
other task depends on. It does three things:

1. **Skeleton for new code** — new files, signatures, types, and data structures, with bodies that raise a "not implemented" error. It does not stub or alter existing functions; changing existing code is the fill-in tasks' job.
2. **All test changes** — adds the tests for `ADDED` behaviors, updates the tests for `MODIFIED` behaviors, and deletes the tests for `REMOVED` behaviors. The full code of every added and changed test is in the plan.
3. **Shared contracts on disk** — after Task 0 is committed, every interface the parallel tasks share exists as real code, so they cannot drift apart.

Tests written at plan time cannot be biased by an implementation, because none
exists yet. After Task 0, execute runs a red check and locks the test files;
executors may add tests but never edit locked ones.

## Tests and Exact Code

Every task carries **full test code** for the behavior IDs it `Covers` — usually
by pointing at the tests Task 0 writes. Tests are the definition of done: an
executor is finished when those tests pass and nothing regresses.

Implementation code appears in the plan **only** in a task's `Exact` block, and
only where the exact text is the point:
- schemas, migrations, and data formats
- public API signatures beyond what the skeleton already fixes
- config file formats
- prompt text and user-facing copy
- genuinely tricky algorithms where a wrong-but-passing implementation is likely

Everything else, the executor writes against the tests. The `Changes` list
still says precisely *what* to implement — behavior, edge cases, error handling
— so no design decision is left open.

**Plan failures — never write:**
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases" — name the cases
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the content)
- A behavior ID from the proposal that no task covers
- References to types, functions, or methods not defined in Task 0, an `Exact` block, or the existing code

In **reduced mode** (no test suite), tasks carry no test code; their `Acceptance`
lists the commands or observations that show the task works, and the checker
grades those at the end.

## Task Granularity

**Target: one reviewable commit per task.** A task is a coherent unit a reviewer
can understand on its own — typically one behavior or one layer of a change.

**Sizing rules:**
- A task with its tests, 1–3 files, and no open design decision → good size
- A task that requires the executor to make design decisions → too large or underspecified; split it or resolve the decision in the plan
- A task that only makes sense together with its neighbor → merge them
- Parallel tasks must write disjoint files, test files included

## Tier Field

Each task records `Tier: Fast | High`. The planner has the most context for
this decision — recording it here saves execute mode from re-deriving it per wave.

- **Fast**: filling in bodies against the task's tests and any `Exact` blocks; 1–3 files; no design decisions left to the executor.
- **High**: Task 0 (always); design judgment; prompt or user-facing-copy edits; any ambiguity; on Cursor, multi-file coordination with cross-module logic.

Execute mode may escalate Fast → High (e.g., when a task's tests stay red) but never downgrades High → Fast.

## Executor Field

Each task records `Executor: subagent | inline`.

- **subagent** (default): dispatched to a fresh `darwin-executor`. Required for every task in a parallel wave and for context-heavy tasks.
- **inline**: implemented by the execute orchestrator itself. Use only for a small task that runs alone in its wave and whose files the orchestrator has already read — the dispatch would cost more than the work. Inline tasks go through the same wave gate.

## Plan Self-Review

Before presenting the plan, run this checklist:

1. **Behavior coverage**: Every `ADDED` and `MODIFIED` ID in the proposal is in some task's `Covers`, with a test (reduced mode: with an `Acceptance` check). Every `REMOVED` ID has its tests deleted in Task 0. Every ticket acceptance criterion maps to an ID.
2. **Placeholder scan**: Search for red flags from the Tests and Exact Code section.
3. **Name/type consistency**: Do function names, types, and field names match across Task 0, the tests, and the `Exact` blocks?
4. **Granularity check**: Is every task one reviewable commit?
5. **Dependency correctness**: Does every task depend on Task 0 (standard mode)? Are parallel tasks truly independent? Do they write different files, test files included?
6. **Tier and Executor sanity**: Does every task have both fields? Is anything marked `Fast` that leaves design decisions, prompt edits, or ambiguity to the executor? Is anything marked `inline` that shares a wave?

## Project-Specific Planning

Refer to your project's `project-context.mdc` for domain-specific planning areas and `development-commands.mdc` for validation commands.

## Next Step

After the plan is approved and committed, hand off to execute. Execution must run inside the worktree, so do **not** auto-invoke execute from the main checkout (execute halts there). Tell the user:

```
Plan approved, worktree created, and plan committed to .darwin/darwin-progress.md on branch <branch>.
Next: move into the worktree — `cd <worktree_path>` (or reopen the session there) — then run `/execute`.
```

If the session is already operating inside `<worktree_path>`, invoke execute directly instead.

If the plan reveals issues requiring alternative approaches, invoke the innovate skill instead.

## Integration

- **Chains to**: `execute` skill (default), `innovate` skill (when plan reveals issues)
- **Invokes**: `using-git-worktrees` (at finalization, to create the feature worktree); `onboarding`'s test-setup step (when the project has no test command)
- **Reads**: `.darwin/proposal.md` (format: `behaviors` skill), `.darwin/config.json` (contract: `execute` skill's Darwin Config), `.cursor/darwin-research.md`
- **Produces**: `.darwin/darwin-progress.md` and `.darwin/proposal.md` (inside the feature worktree, committed on the branch); `.darwin/active-worktree` breadcrumb (at the main checkout root)
- **Defines**: the progress-file schema and Status Vocabulary ([references/progress-file.md](references/progress-file.md))
- **References**: `project-context.mdc`, `code-quality-standards.mdc`, `development-commands.mdc`
- **Consults**: `.darwin/learnings/` lesson frontmatter (format: `compound` skill's `references/lesson-format.md`)
