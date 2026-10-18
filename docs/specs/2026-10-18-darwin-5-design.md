# Darwin 5 — Design

**Date:** 2026-10-18
**Status:** Draft for review (nothing implemented)
**Base:** `main` @ `de550e1` (v4.2.0)
**Target version:** 5.0.0 (breaking: workflow artifacts and agent roster change)

---

## 1. Intent

Darwin is a dual-host (Cursor + Claude Code) workflow plugin in the spirit of Superpowers. It takes work through research, design, planning, execution and review, and it **learns from its mistakes**. That learning loop is why it is called Darwin.

Darwin 4 is built around getting the model to *follow a plan*: plans contain complete code, a cheap executor copies it, and two AI reviewers read the result. Since then, the field and the evidence have moved toward getting the model to *satisfy checks*:
- Tests written before code measurably improve agent results (Google, arXiv 2608.17177: +9.8pp bug detection, p=0.035).
- Evaluators that run the software beat reviewers that only read diffs (Anthropic harness-design post, Mar 2026).
- Process should scale to the task (Anthropic dropped sprint scaffolding for newer models).
- Specs stay useful only if they stay alive with the code (OpenSpec, Kiro, Spec Kit 1.x).

Darwin 5 keeps Darwin's shape and changes five things:
1. **Tests are the contract.** Plans carry full test code plus a code skeleton, not full implementation. "Done" means the tests pass.
2. **One evaluation at the end that runs things**: a checker plus a maintainer review, replacing the two per-task reviewers.
3. **Behaviors.** Living, per-capability descriptions of what the product does, updated by every change, with a strict drift check.
4. **Process sized to the task**: direct, quick, bugfix and feature tracks.
5. **A real evolutionary learning loop.** Lessons are captured everywhere, delivered where they apply, counted, promoted to checks when used often (with approval), and retired when unused.

## 2. Goals, non-goals, anti-goals

**Goals**
- Cheap/fast models still do most of the parallel implementation work.
- "Done" is proven by running commands, with output in the record, not asserted by an agent.
- The human reviews short things: a change proposal (behavior changes), the tests, and a final evidence report. No 500-line plans.
- Behavior documentation that is always current, because the drift check makes it so.
- Lessons that demonstrably reduce repeat mistakes, and a lesson list that stays small.
- Identical behavior on Cursor and Claude Code; host-specific features only where both hosts have an equivalent.

**Non-goals**
- Generating behavior files for a whole repository.
- Replacing host-native features (plan mode, cloud agents) in this version.
- Unattended / background multi-hour runs (a possible later "converge loop").
- Best-of-N parallel candidates (possible later, once tests make picking cheap).

**Anti-goals (failure even if it "works")**
- A quick fix that drags you through ceremony.
- Behavior files that are long, unread or wrong, documentation nobody trusts.
- A drift check people routinely bypass because it blocks harmless work.
- Executors gaming tests (editing them, special-casing them) to go green.
- A learnings list that grows forever and that agents ignore.

## 3. Decisions made in conversation (the user's)

| # | Decision |
|---|---|
| D1 | Keep full code out of plans by default. Middle ground: wave-0 skeleton + full test code in the plan + exact code only where the exact text matters + cheap model first, escalate on red. |
| D2 | Living specs are adopted and named **behaviors**, stored in `.darwin/behaviors/`. |
| D3 | The drift check is **strict**. |
| D4 | Behaviors are **on by default** (off switch in config). |
| D5 | Repos with no test setup: **stop and offer to set one up**, as part of onboarding, together with initial behavior file creation. |
| D6 | Checker and maintainer review run **once, at the end of the feature**. No per-task review. |
| D7 | Lessons are promoted **only when used often**, and promotion to a check **requires user approval**. |
| D8 | Research and innovate keep their processes and get the targeted changes in §6.3–6.4. |
| D9 | Feature track when the user **declines** test setup: proceed in a **reduced mode**, not a hard stop (user deferred to my suggestion). Reduced mode is the same as legacy mode (§9): no wave 0 or red check; tasks are gated on `Acceptance` checks and a clean tree; the checker grades `Acceptance` criteria and behavior IDs by inspecting and exercising the app. The proposal records "no test suite", and the offer repeats at the next feature. |
| D10 | **No constitution cleanup in 5.0.** The `[MODE]` tag, the constitution's length and the prompting style stay. The constitution gets only the content updates the new flow needs (§6.12). |
| D11 | **Pushing is never automated.** Darwin pushes only on the user's explicit request (`git-ship`, or the finishing "push and create MR" option). No push hook. |
| D12 | **Drop the generated architecture overview.** `project-context.mdc` keeps only commands, non-standard conventions, gotchas and project safety rules; the Overview, Key Modules, Entry Points and Architecture sections go. Behaviors carry the "what lives where" role. |

Calls I made are marked **[call]** throughout and listed in §13 for review.

## 4. The flow at a glance

```
start ─► choose track (one line, user can override)
         ├─ direct  : edit ─► run tests/lint ─► drift check ─► commit
         ├─ quick   : mini-plan ─► edit ─► tests/lint ─► behavior edit if needed ─► drift check ─► commit
         ├─ bugfix  : root cause ─► regression test (red) ─► fix (green) ─► drift check ─► commit
         └─ feature :
              research (reads behaviors + lessons for the area; reports test setup)
                 ▼
              innovate (optional) ─► CHANGE PROPOSAL: behavior deltas + how each is verified   ◄─ user approves
                 ▼
              plan: Task 0 skeleton+tests, tasks covering behavior IDs, tiers                  ◄─ user approves
                 ▼
              finalize: worktree ─► baseline test run recorded
                 ▼
              execute: wave 0 (strong model) skeleton + tests ─► red check ─► lock tests
                       waves 1+ (fast model, parallel) fill bodies until own tests green
                         └─ red after 2 dispatches ─► re-dispatch on strong model
                       after each wave: full suite + test-lock check
                 ▼
              apply behavior deltas to .darwin/behaviors/
                 ▼
              end-of-feature evaluation: checker (runs suite, mutation probes, exercises app, PASS/FAIL per ID)
                                         + maintainer review ("would maintainers merge this?")
                 ▼
              compound (learnings: capture, count, propose promotions/retirements)
                 ▼
              finishing: strict drift check ─► archive proposal+plan ─► merge / MR
```

## 5. Core concepts

### 5.1 Behavior files

**Location:** `.darwin/behaviors/<capability>.md`, committed.
**Capability:** a user-facing area of behavior ("export", "auth", "scan-scheduling"), not a code folder.

**Format:**
```markdown
---
capability: export
paths: [src/export/, src/api/export_routes.py]
---
# Export
Purpose: users download scan results as CSV or JSON.

### EXPORT-1: Empty results
Status: intended
WHEN a user exports a scan with no findings
THEN the file contains only the header row
Tests: tests/export/test_csv.py::test_empty_export

### EXPORT-2: Large exports stream
Status: observed
WHEN an export exceeds 100k rows
THEN rows are streamed and memory stays bounded
Tests: tests/export/test_stream.py::test_streams_large_export
```

Rules:
- **IDs** are `<CAPABILITY>-<n>`, unique, and never reused after removal.
- **`Status: observed`** marks behavior recorded from existing code (it may encode a bug). **`Status: intended`** marks behavior a human decided or confirmed. Observed becomes intended when a human confirms it, either during onboarding review or when a change proposal touches it.
- **`Tests:`** is one or more `path::test-name` pointers. Every intended requirement must have at least one. An observed requirement may say `Tests: none yet`, which the checker reports and the drift check allows.
- **What, never how.** No implementation details, class names or algorithms.
- **Size:** about 150 lines per file. Past that, split the capability.
- **`paths`** are path prefixes or globs. They drive research lookup, lesson delivery and the drift check.

### 5.2 Change proposal

Every feature produces one short **change proposal**. It replaces today's design-in-conversation (the plan skill currently says the approved approach "lives in the main-session conversation, not in any file").

```markdown
# Change: Stream large exports
Why: exports over ~100k rows time out and exhaust memory.
Approach: <chosen approach, 3–10 lines>; rejected: <alternatives, one line each>
Out of scope: <list>

## Behavior changes
ADDED    EXPORT-7: WHEN an export exceeds 100k rows THEN rows stream ...   Verify: unit test
MODIFIED EXPORT-2: <new WHEN/THEN>                                        Verify: integration test
REMOVED  EXPORT-4: <reason>
NEW CAPABILITY report-sharing (creates .darwin/behaviors/report-sharing.md)
```

Lifecycle:
- Written by **innovate**, or by **plan** when innovate was skipped. It sits at `.darwin/proposal.md` in the main checkout until plan finalization moves it into the worktree, the same way the progress file moves today.
- Approved by the user. **This is the main human review artifact.**
- At finishing it is archived with the plan to `.darwin/archive/<slug>/` (`proposal.md` + `plan.md`). That replaces `.darwin/plans/<slug>.md` **[call]**. The existing `.darwin/plans/` stays as is for history.

### 5.3 Tests as the contract

- Each plan task carries **full test code** for the behavior IDs it covers.
- **Task 0 (wave 0)** runs on the strong model. It writes the **skeleton** for *new* code (new files, signatures and types, with bodies raising a "not implemented" error) and applies **all test changes** from the plan:
  - new tests for ADDED behaviors;
  - updated tests for MODIFIED behaviors;
  - deleted tests for REMOVED behaviors.

  It does not stub or alter existing functions. Changing existing code is the fill-in tasks' job.
- **Exact implementation code** appears in the plan only where the exact text is the point: schemas, migrations, public API signatures, config formats, prompt/copy text, tricky algorithms. The planner marks these `Exact: yes`.
- **Locked tests.** After wave 0 the orchestrator records a hash of every *test-support* file in the progress file (`Test lock` table). The hash is `git hash-object`, which is identical on macOS and Linux. Test-support files are:
  - every file wave 0 wrote or changed;
  - every file under the project's test directories (fixtures, `conftest.py`, snapshots);
  - the test-runner configs (e.g. `pytest.ini`, `jest.config.*`, the test sections of `pyproject.toml`/`package.json` as whole files).

  The orchestrator re-hashes them after each wave. A changed hash rejects the responsible task's result. This is host-agnostic and needs no hook **[call]**.
- Executors may **add** new test files of their own. They may not modify locked ones.
- **A test that turns out to be wrong:** the executor reports `BLOCKED: test defect` with its reasoning. The orchestrator asks the user which to fix (the code, the test, or the behavior) and re-locks after the change.
- Tests point back to behavior IDs through the behavior file's `Tests:` pointers. That link is authoritative. Putting the ID in the test name is optional.

## 6. Component designs

### 6.1 Track choice

At the start of any request the model states the track in one line ("Treating this as a quick change: 2 files, no design questions"), and the user can override. Criteria:

| Track | When |
|---|---|
| direct | The diff fits in one sentence; obvious location |
| quick | Small, clear, fully describable before starting; no open design question |
| bugfix | Something is broken, with expected behavior known or knowable |
| feature | New or changed behavior, multi-file and uncertain, unfamiliar code, or shared contracts |

Direct and quick run the project's test/lint commands when they exist, and run the drift check before committing. A quick change that alters described behavior edits the behavior file in the same commit. Bugfix uses `systematic-debugging` to find the root cause, then a regression test that fails, then the fix. If the fix grows past quick size, it escalates to the feature track. If the bug contradicts an intended behavior, the code is wrong. If the behavior file itself is wrong, the fix includes the behavior edit.

**Repos with no test command (D5, D9):** the feature and bugfix tracks stop and offer onboarding's test-setup step. If the user declines, the work proceeds in reduced mode (D9). Direct and quick proceed with a one-line warning **[call]**.

### 6.2 Onboarding

New and changed phases:
1. **Commands.** Detect test, scoped-test, lint, typecheck and run commands. Write them to `.darwin/config.json` (machine-readable, for skills, scripts and hooks) and to `development-commands.mdc` (human-readable).
2. **Test setup (when none exists).** Propose a minimal setup: the standard framework for the language, one smoke test that passes, and the commands saved to config. Ask before installing dependencies. Skippable, but the feature and bugfix tracks will ask again.
3. **Initial behaviors.** Propose a list of the repo's main capabilities with suggested `paths`. The user picks which to capture now. For each pick, draft a short behavior file from the code and tests with every requirement `Status: observed`. The user reviews it and may promote items to intended. Everything else is captured lazily, by the first feature that touches it.
4. **Slimmer generated rules (D12).** `project-context.mdc` keeps only commands, non-standard conventions and gotchas. Drop the generated architecture and module overviews (the ETH AGENTS.md study found generated overviews hurt in 5 of 8 settings and cost more than 20% extra). The CLAUDE.md managed block shrinks accordingly.

### 6.3 Research

Keep the `darwin-researcher` subagent, the report file and the refinement loop. Changes:
- **Behaviors first:** find behavior files whose `paths` match the topic and read them before code. If a matching area has no behavior file, the report flags it, and the proposal will create one.
- **Test setup section:** the "Test coverage map" becomes "Test setup & coverage": is there a runnable test command, how tests are organized, which existing tests cover this area, and the fixtures and helpers available.
- **Lessons:** report active lessons whose scope matches the area.
- **Ticket acceptance criteria → draft behavior changes** (the first draft of the proposal's ADDED/MODIFIED list).
- **Relax the main-session read ban:** the orchestrator may read a few files directly for small lookups.
- *(Dropped from this version: parallel researchers. The researcher overwrites a single report file and can't edit, so parallel runs would need separate files plus a merge step. Revisit later.)*

### 6.4 Innovate

Keep the conversational process: one question at a time, 2–3 options with a recommendation, design in sections. Changes:
- **Ends by writing the change proposal** (§5.2), including **how each behavior change will be verified** (unit, integration, or exercising the app).
- **Skippable:** when there is one obvious approach, the flow goes research → plan, and plan writes the proposal.

### 6.5 Plan

Changes:
- **Input:** the approved change proposal (a file, not conversation memory).
- **Task 0:** skeleton + all tests, Tier High.
- **Tasks:** each has `Covers: EXPORT-7, EXPORT-2`, `Tier`, `Files`, `Depends on`, `Tests` (full test code), an optional `Exact` code block, and acceptance as runnable commands.
- **Task size:** "one reviewable commit" replaces "10–15 minutes".
- **Self-review checks:**
  - every proposal ID is covered by at least one task with a test;
  - parallel tasks don't write the same files, test files included;
  - no behavioral placeholders ("add appropriate error handling" is still a plan failure).
- **Finalization (unchanged steps plus):** move `proposal.md` into the worktree with the progress file (step 10.4). Run the **baseline** (§6.6) right after that move, because the progress file has to be in the worktree to record it. Commit both files in the existing plan commit (step 10.6).

**Progress file schema additions:**
- Overview: `Proposal: .darwin/proposal.md`, `Baseline: pass | N failing (<ids>)`.
- Task fields: `Covers`, `Tests`, `Exact`.
- New sections: `## Test lock` (path, sha256) and `## Lessons delivered` (lesson ID → tasks).

### 6.6 Worktree and baseline

`using-git-worktrees` runs project setup (as today). The **plan skill** then runs `commands.test` once in the worktree, after moving the progress file in, and records the result in the Overview. Telling which tests failed means parsing runner output; see §14. If the baseline fails, ask the user: proceed with the failures recorded as known (they are excluded from later gating), or stop.

### 6.7 Execute

1. Enter and verify the worktree (as today).
2. **Wave 0:** dispatch Task 0 on the strong model. Then the **red check**: run the new and changed tests. Every one must be *collected and run*: collection, import or syntax errors fail the red check, and Task 0 is re-dispatched. The expected outcome depends on the delta type:
   - tests for ADDED behaviors fail, with "not implemented" or an assertion failure;
   - tests for MODIFIED behaviors fail on an assertion, because the old code still does the old thing;
   - tests that unexpectedly *pass* are flagged to the user. A test that passes before the change proves nothing.

   Then record the **test lock**. The post-wave full-suite check is skipped for wave 0.

   The orchestrator keeps an **expected-red set**: the locked tests belonging to tasks not yet complete. Later suite runs exclude it, along with baseline failures.
3. **Waves 1+:** dispatch ready tasks in parallel on their tier's model.
   - Each executor gets its task block, read-first pointers, dependency summaries, and the **lessons scoped to its files** (at most 5).
   - It runs **only its own tests** using `commands.testScoped`, so parallel executors don't collide.
   - It reports **evidence**: command, exit code, last ~20 lines of output, plus a `Lessons` line per delivered lesson (`L-12: applied | not relevant`).
4. **Gate (mechanical, by the orchestrator, once the wave has returned):**
   - for each task, re-run its own tests;
   - verify the test lock;
   - check that `git status` shows only files in the wave's combined file set plus newly added test files. Per task isn't possible mid-wave, because siblings' files show up too.

   Each passing task is committed separately (`type(scope): Task N — title`, staging only that task's files) and set to `COMPLETE`, which now means "passed the gate and committed".

   A task with red tests is re-dispatched once with the failure output, as a **fresh executor given that task's context**. If still red, it is escalated to the High tier. A second High failure goes to the user.
5. **After each wave (from wave 1):** run the full suite, excluding baseline failures and the expected-red set. A cross-task breakage becomes a fix task, given to a fresh executor with the context of the latest task that touched the failing area.
6. **Apply behavior deltas** from the proposal to `.darwin/behaviors/*.md` (the orchestrator is the single writer). New capability files are created here. Commit `docs(behaviors): apply <change> deltas`.
7. **End-of-feature evaluation** (§6.8), then compound (§6.11), then finishing (§6.10).

**Tier → model mapping** is unchanged in structure (profiles economy/balanced/quality; Claude `haiku`/`sonnet`/`opus`; Cursor `fast`/omit). Fast is the default for fill-in tasks. Profiles now also toggle mutation probes (off under economy) **[call]**.

**Inline execution:** with the orchestrator now gating mechanically, the planner may mark small sequential tasks `Executor: inline` for the orchestrator to implement directly. Parallel waves always use subagents **[call]**.

### 6.8 End-of-feature evaluation

Both reviewer agents are replaced:

**`darwin-checker`** (replaces `darwin-spec-reviewer`):
- Works **in the feature worktree**, which is safe because nothing else runs there at this point. A scratch worktree would need a full dependency install and risk port collisions.
- Runs the full suite and lint/typecheck.
- **Mutation probes:** for the changed lines, applies a handful of small mutations (flip a condition, drop a call, change a boundary), one at a time. After each it runs the relevant tests, then restores the file with `git checkout -- <file>`. A survivor means the tests don't really constrain that line. Uses `commands.mutation` instead if the project has a mutation tool configured.
- **Afterwards, the orchestrator checks the tree is clean** (`git status`). If it isn't, the orchestrator restores it and reports that.
- **Exercises the app** when `commands.run` exists and the change is user-facing. Uses Playwright MCP for UI if it is configured and visible to subagents on that host; otherwise the CLI or HTTP. Playwright is not added to `mcp.json`/`.mcp.json` by Darwin.
- Output:
  - a table of every ADDED/MODIFIED behavior ID: PASS or FAIL, with evidence;
  - REMOVED IDs confirmed gone;
  - surviving mutants;
  - findings graded blocking or non-blocking.
- Frontmatter: not read-only, because it must apply mutants. The clean-tree check is the enforcement.
- **Verdict heading** (a fixed string that finishing and resume look for, replacing `### Final Review — ✅ Review approved`): `### Evaluation — ✅ Approved`, or `### Evaluation — ❌ Escalated`.

**`darwin-maintainer-reviewer`** (replaces `darwin-quality-reviewer`):
- Read-only.
- Inputs: the feature diff (`git diff <base>...HEAD`), `code-quality-standards.mdc`, and lessons scoped to the touched files.
- One question: would this repo's maintainers merge it? Covers conventions, scope creep, dead code, test quality, risky patterns. **Not style**; linters own style.
- Output: blocking and non-blocking findings.

**Loop:** blocking findings from either agent become fix tasks (routed to the owning task's executor), followed by the per-task gate and a re-run of the agent that found them. There is a 3-loop budget, then escalation to the user (as today).

### 6.9 Drift check (strict)

**Script:** `scripts/behavior-check.sh` in the plugin, invoked the same way `archive-plan.sh` is today. It reads `.darwin/config.json` and `.darwin/behaviors/`.

**Inputs:**
- The base ref: from the progress file `Base`, else the `merge-base` with `origin/HEAD`.
- The changed files: `git diff --name-only <base>...HEAD`, plus staged files when run before a commit.

**Rules (non-zero exit on any violation):**
1. **Covered capability touched.** Each capability whose `paths` match a changed file must either have its behavior file changed on the branch, or have a commit on the branch carrying `Behavior-Change: none (<capability>) — <reason>`.
2. **Integrity:**
   - every `Tests:` pointer resolves: the file exists and contains the test name;
   - IDs are unique;
   - removed requirements stay in the file as **tombstones** (`### EXPORT-4: <title>` + `Status: removed` + one-line reason, no `Tests:`), so their IDs are never reused.
   - The checker (not this script) confirms the tests for removed behaviors were deleted.
3. **Uncovered code.** Changed files that match no behavior file's `paths`:
   - on a branch that **carries a change proposal** (a commit on the branch added `.darwin/proposal.md`, or the archived copy): **error**. The proposal should have created or extended a capability. This identifies the feature track mechanically, with no stored track **[call]**;
   - on any other branch (quick/direct): **warning only** **[call]**;
   - `behaviors.strictUncovered: true` makes it an error everywhere.
4. **No-op** when `behaviors.enabled` is false or `.darwin/behaviors/` doesn't exist: repos that never ran the v5 onboarding are unaffected.

**Where it runs:**

| Point | Effect |
|---|---|
| `finishing-development-branch` | Blocks the merge/MR options until it passes |
| `quick`, direct track, `git-ship` | Runs before committing |
| CI (optional) | A documented CI job snippet (GitHub Actions or GitLab CI); teams opt in |

There is **no push hook** (D11). Pushing is never automated: Darwin pushes only when the user explicitly asks, through `git-ship` or the "push and create MR" finishing option. The check runs at commit and finishing time instead.

### 6.10 Finishing

- **Step 1 (readiness)** additionally requires: the evaluation verdict recorded, behavior deltas applied, and the drift check passing.
- **Archive:** proposal + plan to `.darwin/archive/<slug>/` (replaces `archive-plan.sh` with `archive-change.sh`).
- **MR description template:**
  - the behavior changes (from the proposal);
  - the checker's PASS/FAIL table;
  - the evidence summary.

  Human reviewers see the behavior diff next to the code.

### 6.11 Learnings loop

**Storage: no shared mutable file [call].** Today's `index.json` is committed (in onboarded repos `.cursor/` is tracked, so worktrees have their own branch copy). Two features in flight would conflict on the counters at merge. So:
- **Lessons move to `.darwin/learnings/`**, committed, one file per lesson. Metadata lives in each file's frontmatter. Lessons are append-only new files, so they never conflict.
- **Usage is an append-only event log, one file per branch:** `.darwin/learnings/usage/<branch-slug>.jsonl`. Each line is `{lesson, event: delivered|applied|not-relevant|recurrence, task, date}`. Every branch writes its own file, so they never conflict.
- **Counts are derived**, by summing all usage files whenever compound or the orchestrator needs them. `index.json` goes away; selecting lessons means scanning frontmatter (a `grep`).
- **Status changes** (`promoted`, `retired`) edit the lesson's own frontmatter. These are rare, single-line edits.

**Lesson frontmatter:**
```yaml
id: L-12
category: gotcha
summary: Scan API returns UTC; convert before display
scope: [src/scans/, src/ui/dates.ts]
status: active        # active | promoted | retired
promotedTo: null
```

**Capture: everywhere.**
- End of feature (compound, as today).
- End of quick/bugfix when something went wrong (an escalation, a red-test loop, a user correction). One question, not a ceremony.
- The end of `systematic-debugging`.
- When the user corrects the agent mid-task, the agent offers to record a lesson. The agent does this, not a hook; hooks must not infer intent (CLAUDE.md).

**Delivery: where it applies.** The orchestrator selects active lessons whose `scope` matches a task's files and includes up to 5 in the prompts for the executor, checker and maintainer reviewer. Research shows them to the user.

**Counting (derived from the usage logs):**
- `uses` = the number of `applied` events.
- `recurrences` = the number of `recurrence` events, written when the checker, maintainer reviewer or user catches a mistake an existing lesson describes.
- `irrelevantStreak` = trailing `not-relevant` events since the lesson was last applied.
- The orchestrator appends events on the feature track. On quick/bugfix/debugging, only `recurrence` events are written (no delivery bookkeeping there) **[call]**.

**Promotion (D7):** when `uses + recurrences ≥ learnings.promoteAt` (default 3), compound **proposes** turning the lesson into a check, in order of preference:
1. a lint rule in the project's existing linter config;
2. a test;
3. a hook;
4. a path-scoped rule, written for **both hosts**: Cursor `.cursor/rules/<name>.mdc` with `globs`, and Claude Code `.claude/rules/<name>.md` with `paths` frontmatter. The two formats differ, so it takes two files; confirm the Claude mechanism against current docs at build time.

**The user approves each one.** Approved → `status: promoted`, `promotedTo: <path>`. The lesson stops being delivered, because the check now enforces it.

**Retirement:** `irrelevantStreak ≥ learnings.retireAfter` (default 10 deliveries) → compound lists it as retiring. It becomes `status: retired` unless the user objects. Nothing is deleted.

**Migration:** compound's first v5 run moves `.cursor/darwin-learnings/*.md` to `.darwin/learnings/`. It converts v1 `index.json` entries into frontmatter (`files` becomes `scope`, an `id` is assigned, status is active) and then removes `index.json`. The session hooks' `.pending-session` marker moves with it.

### 6.12 Constitution (functional updates only — D10)

The constitution cleanup is **out of scope**: no slimming, the `[MODE: X]` tag stays, and the existing prompting style stays.

`rules/framework.mdc` and `skills/using-darwin/SKILL.md` still need **content** updates so they describe the new flow:
- the four tracks;
- the change proposal and behaviors;
- the renamed agents;
- the updated skill table and workflow line.

Edit both in parity, as today. The new agents follow the existing convention (`darwin-checker` declares `[MODE: REVIEW]`, as the reviewers do today).

## 7. Configuration (`.darwin/config.json`)

```json
{
  "profile": "balanced",
  "commands": {
    "test": "pytest -q",
    "testScoped": "pytest -q {files}",
    "lint": "ruff check {files}",
    "typecheck": "pyright",
    "run": "uvicorn app.main:app --port 8000",
    "timeoutSec": 600
  },
  "behaviors": { "enabled": true, "strictUncovered": false },
  "learnings": { "promoteAt": 3, "retireAfter": 10 },
  "checker": { "mutationProbes": true, "exerciseApp": "auto" }
}
```

All keys are optional. A missing `commands.test` is how "no test setup" is detected.
- **Fallbacks:** `testScoped` falls back to `test`, and `commands.mutation` (optional) falls back to the checker's own probes.
- **The file is committed [call]**, so the worktree, hooks and scripts all see the same values. Execute already reads it from the worktree first, then the main checkout.
- **Profiles:**
  - `economy`: cheaper models, no mutation probes;
  - `balanced`: today's models, probes on;
  - `quality`: always exercise the app, plus more mutants per changed hunk.

  Without per-task review, the profiles otherwise share models.

## 8. Cross-host notes

| Concern | Cursor | Claude Code |
|---|---|---|
| Test lock | Orchestrator hash check (no hook) | Same |
| Checker scratch worktree | Agent without `readonly` | Agent without `disallowedTools` |
| Maintainer reviewer read-only | `readonly: true` | `disallowedTools: Write, Edit, NotebookEdit` |
| Model per tier | `fast` / omit | `haiku` / `sonnet` / `opus` by profile |
| Path-scoped promoted rules | `.mdc` with `globs` | To confirm (path-scoped rules mechanism) |
| Everything else | Markdown + bash; identical | Identical |

`mcp.json` and `.mcp.json` are unaffected unless Playwright MCP is added. If it is, add it to both files.

## 9. Back-compat and migration

- **v4 progress files** (no `Covers`/`Tests`/`Test lock`): execute runs them in **legacy mode** **[call]**:
  - no wave 0, red check or behavior deltas;
  - gate = run `commands.test` if present, plus the clean-tree check;
  - the checker grades each task's `Acceptance` criteria instead of behavior IDs;
  - the maintainer review runs as normal.

  `/resume` detects legacy mode from the missing fields.
- `.darwin/plans/` archive: left as is; new archives go to `.darwin/archive/`.
- Learnings index v1 → v2: migrated in place on first compound run.
- Repos onboarded with v4: the session-start hook suggests the new onboarding steps (commands, tests, behaviors) once per repo. It uses a new marker `darwin-v5-onboarding-suggested` in the git common dir, alongside the existing one, and fires when `project-context.mdc` exists but `.darwin/config.json` has no `commands`.

## 10. File change map

| File | Change |
|---|---|
| `rules/framework.mdc`, `skills/using-darwin/SKILL.md` | Content updates in parity: tracks, proposal, behaviors, renamed agents, skill table (no cleanup — D10) |
| `skills/quick/SKILL.md` | Direct + quick tracks, test run, behavior edit, drift check |
| `skills/systematic-debugging/SKILL.md` | Bugfix track: regression test first |
| `skills/research/SKILL.md`, `agents/darwin-researcher.md` | Behaviors first, test setup section, lessons, draft deltas, relaxed read ban |
| `skills/innovate/SKILL.md` | Writes the change proposal, verification per change, skippable |
| `skills/plan/SKILL.md` (+ references) | Proposal input, Task 0, tests in plan, `Covers`/`Exact`, new schema, baseline at finalization |
| `skills/using-git-worktrees/SKILL.md` | Baseline run |
| `skills/execute/SKILL.md` (+ references) | Wave 0, red check, test lock, scoped tests, mechanical gate, post-wave suite, apply deltas, legacy mode |
| `agents/darwin-executor.md` | Fill-in role, scoped tests, evidence + lessons report, test-defect status |
| `skills/reviewing-implementation/SKILL.md` | Rewritten as end-of-feature evaluation orchestration |
| `agents/darwin-spec-reviewer.md` → `agents/darwin-checker.md` | New role |
| `agents/darwin-quality-reviewer.md` → `agents/darwin-maintainer-reviewer.md` | New role |
| `skills/compound/SKILL.md` | Learnings v2: `.darwin/learnings/`, per-branch usage logs, derived counts, promotion proposals, retirement, migration from `.cursor/darwin-learnings/` |
| `hooks/session-start.sh`, `hooks/session-end.sh`, `hooks/lib.sh` | `.pending-session` marker path moves to `.darwin/learnings/` |
| `skills/onboarding/SKILL.md` (+ references) | Commands → config, test setup, initial behaviors, slimmer generated rules |
| `skills/finishing-development-branch/SKILL.md` | Readiness incl. drift check; archive change; MR template |
| `skills/git-ship/SKILL.md`, `skills/fix-all/SKILL.md` | Drift check before ship; read commands from config |
| `skills/resume/SKILL.md` | New fields, legacy detection |
| `scripts/behavior-check.sh` (new), `scripts/archive-change.sh` (new, replaces `archive-plan.sh`) | |
| `hooks/session-start.sh`, `hooks/test-hooks.sh` | v4→v5 onboarding suggestion, with tests (`before-shell.sh` unchanged) |
| `README.md`, `CLAUDE.md`, `CLI-SUPPORT.md` | Document the new flow, agents, files |
| `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `marketplace.json` | 5.0.0 |
| `skills/plan/SKILL.md` Status Vocabulary | `COMPLETE` redefined: "passed the gate and committed" |
| Cross-references | grep for `darwin-spec-reviewer`, `darwin-quality-reviewer`, `[MODE:`, `darwin-progress`, `.darwin/plans`, `Final Review — ✅`, `darwin-learnings`, `index.json` |

## 11. Verifying Darwin itself

1. `bash hooks/test-hooks.sh`, extended for the session-start suggestion and the moved `.pending-session` marker, on both payload shapes.
2. **Script tests:** a small fixture repo under `tests/fixtures/` exercising `behavior-check.sh`:
   - covered change with no update → fail;
   - covered change with a `Behavior-Change: none` trailer → pass;
   - broken `Tests:` pointer → fail;
   - duplicate ID → fail;
   - uncovered change on the quick track → warn.
3. **End-to-end dry run** on a throwaway project, on both hosts: onboarding, a feature with ADDED and MODIFIED behaviors and parallel tasks, a quick change, a bugfix, and a feature in reduced mode. *(A before/after eval set was considered and dropped by the user.)*
4. Read every changed skill and agent end to end; confirm all cross-references resolve.

## 12. Risks

| Risk | Mitigation |
|---|---|
| Plans still grow large (test code instead of implementation) | Tests are typically shorter than implementations, and the human reviews the proposal, not the plan. Reconsider if eval plans exceed ~600 lines |
| Cheap models fail at filling bodies on Cursor | Red-test escalation to High; watch the escalation rate in the dry run and early use |
| Parallel executors share one worktree: scoped test runs still share caches, databases and ports, and half-written edits can break a sibling's imports | Wave 0's red check guarantees the skeleton imports cleanly before waves start; executors edit only their own files; scoped tests only; `execute.serialWaves: true` config for projects that still collide. Per-task worktrees are a possible later step |
| Strict drift check feels like friction | `Behavior-Change: none` trailer; warning-only for uncovered quick work; a precise denial message |
| Observed behaviors encode bugs | `Status: observed` until confirmed; the checker doesn't treat observed as intended |
| Mutation probes are slow | Changed lines only, a handful of mutants, off under economy |
| Lesson counting depends on agents reporting honestly | Recurrences are counted from checker/user findings, not self-report; retirement is reversible |
| Big-bang release | Phased implementation (below); legacy mode for in-flight plans |

**Suggested implementation phases:**
1. Config + onboarding commands/test setup + baseline.
2. Tests-as-contract execution (wave 0, red check, lock, gates) + executor.
3. Checker + maintainer reviewer.
4. Behaviors + proposal + drift check + finishing.
5. Learnings v2.
6. Constitution/hygiene + progressive disclosure.
7. End-to-end dry run.

## 13. Calls I made — please check

1. Archive moves to `.darwin/archive/<slug>/`; old `.darwin/plans/` kept.
2. Test lock: the orchestrator hashes all test-support files with `git hash-object` (no hook).
3. Repos without tests: direct/quick proceed with a warning; only feature/bugfix stop.
4. Uncovered code: an error on branches with a change proposal, a warning otherwise (switchable).
6. *(Now decided as D12.)*
7. Planner may mark small sequential tasks `Executor: inline`.
8. Profiles: economy = no mutation probes; quality = always exercise the app plus more mutants.
9. Learnings move to `.darwin/learnings/` with per-branch usage logs and derived counts. `index.json` goes away.
10. Legacy mode for v4 progress files, with the checker grading task `Acceptance`.
11. *(Dropped: the behavioral eval set. The user decided against it.)*
12. Agent renames: `darwin-checker`, `darwin-maintainer-reviewer`.
13. The checker mutates in the feature worktree and restores; the orchestrator verifies a clean tree.
14. `.darwin/config.json` is committed.
15. Parallel researchers dropped from this version.

## 13a. Open questions for the user

All three are answered and folded in as D9–D11 in §3.

## 14. Left to the builder

- Exact wording of skills and agents (match the existing skeleton and voice).
- Mutation probe heuristics per language, and integrating existing mutation tools.
- How `behavior-check.sh` resolves `path::name` for each language (grep-based is acceptable).
- Detection tables for test frameworks during onboarding.
- Per-runner parsing of test output, which the baseline exclusions, the red check and the expected-red set all need (pytest, jest/vitest, go test, cargo test at minimum).
- The CI snippet (GitHub Actions and GitLab CI).

## Sources

- Spec-driven test generation, Google: https://arxiv.org/abs/2608.17177
- Anthropic harness design: https://www.anthropic.com/engineering/harness-design-long-running-apps
- Anthropic long-running harnesses: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- ETH AGENTS.md study: https://arxiv.org/abs/2602.11988
- METR, test-passing PRs and mergeability: https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/
- Plan quality: https://arxiv.org/abs/2604.12147
- OpenSpec: https://github.com/Fission-AI/OpenSpec
- Kiro correctness / PBT: https://kiro.dev/docs/specs/correctness/
- GitHub Spec Kit: https://github.com/github/spec-kit
- Böckeler on SDD tools: https://www.martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html
- Böckeler on harness engineering: https://www.martinfowler.com/articles/exploring-gen-ai/harness-engineering-memo.html
- Claude Code hooks / skills / subagents: https://code.claude.com/docs/en/hooks.md · https://code.claude.com/docs/en/skills.md · https://code.claude.com/docs/en/sub-agents.md
- Cursor hooks / skills / subagents: https://cursor.com/docs/agent/hooks · https://cursor.com/docs/context/skills · https://cursor.com/docs/context/subagents
