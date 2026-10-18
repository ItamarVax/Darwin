---
name: reviewing-implementation
description: End-of-feature evaluation for Darwin, plus manual code review. Use after all execute tasks are complete, when the user asks for a code review, or when resume finds a finished plan with no evaluation verdict. Dispatches darwin-checker (runs the suite, mutation probes, the app; grades each behavior ID) and then darwin-maintainer-reviewer (would the maintainers merge it?).
---

# Reviewing Implementation

The end-of-feature evaluation. It answers two questions, in order:

1. **"Does it work, and do the tests prove it?"** — `darwin-checker` runs things: the full suite, lint and typecheck, mutation probes on changed lines, and the app when relevant, then grades every behavior ID PASS/FAIL with evidence.
2. **"Would this repo's maintainers merge it?"** — `darwin-maintainer-reviewer` reads the whole feature diff for conventions, scope creep, dead code, test quality, and risky patterns. Not style — linters own that.

There is no per-task AI review. During execution, each task is gated
mechanically (its tests, the test lock, a clean tree — see the `execute`
skill's `references/gates.md`). This skill runs **once, after the last wave**.
It orchestrates the two agents; it does not perform reviews itself.

## When This Skill Fires

- The `execute` skill invokes it after all tasks are COMPLETE and behavior deltas are applied (Execution Flow step 11)
- `resume` finds every task COMPLETE but no `### Evaluation —` heading in the Execution Log
- User explicitly asks for a code review (manual mode — see below)

## Constraints

- **Allowed**: Dispatching `darwin-checker` and `darwin-maintainer-reviewer`, turning blocking findings into fix tasks, running the execute skill's wave gate for fix tasks, restoring the working tree after the checker, writing the verdict to the Execution Log
- **Forbidden**: Reviewing the code yourself instead of dispatching, running the two agents in parallel (the checker temporarily mutates files the maintainer reviewer would read), editing locked tests, exceeding the fix-loop budget without escalating

## Inputs

Gather these from the worktree before dispatching:

- **Base ref**: the Overview's `Base` field
- **Proposal**: `.darwin/proposal.md` (absent in legacy mode)
- **Behavior files touched**: the `.darwin/behaviors/*.md` files the proposal changes
- **Plan Overview and task table**: from `.darwin/darwin-progress.md` — including `Baseline`, `Mode`, and each task's `Acceptance`
- **Config**: `commands.*` and `checker.*` from `.darwin/config.json`, and the active profile (the `execute` skill's Darwin Config section)
- **Lessons**: the active lessons scoped to the feature's changed files (may be empty)

## Model Selection

Use the evaluation rows of the shared table in
[../execute/references/model-selection.md](../execute/references/model-selection.md).
When re-dispatching after a fix loop, keep the same model.

## Process

### Step 1 — Checker

Dispatch `darwin-checker` with the `Task` tool:

```
Task tool call:
  subagent_type: "darwin-checker"
  model: <per model-selection.md>
  prompt: |
    End-of-feature check. Mode: <standard | reduced | legacy>. Profile: <profile>.

    ## Base ref
    <Base>

    ## Change proposal
    <contents of .darwin/proposal.md, or "none (legacy mode)">

    ## Behavior files touched
    <paths>

    ## Plan Overview and task table
    <Overview (incl. Baseline and Mode) and task table, with each task's Acceptance>

    ## Config
    <commands.* and checker.* values>

    ## Lessons
    <L-<n>: summary — one per line, or "none">
```

When it returns:

1. **Check the tree**: run `git status --porcelain`. If anything is modified, restore it (`git checkout -- <file>`) and note it under the verdict — a checker that leaves mutants behind is itself a finding.
2. **Read the verdict** (the last line, `Verdict: approved | changes needed`) and its blocking findings.

### Step 2 — Maintainer review

Only after Step 1's tree check. Dispatch `darwin-maintainer-reviewer`:

```
Task tool call:
  subagent_type: "darwin-maintainer-reviewer"
  model: <per model-selection.md>
  prompt: |
    End-of-feature maintainer review.

    ## Base ref
    <Base>

    ## Change proposal
    .darwin/proposal.md (or "none" — skip the scope-creep check)

    ## Standards
    <path to code-quality-standards.mdc, or "none">

    ## Lessons
    <L-<n>: summary — one per line, or "none">
```

Run it even when the checker said `changes needed`, so one fix loop can address both sets of findings.

### Step 3 — Fix loop

When either agent reports blocking findings:

1. **Make fix tasks**: one per blocking finding (or per owning task when several findings share it). The owner is the task whose `Files` include the affected file; if several did, the latest. Record each fix task in the progress file's task table as `F<n>` with status `PENDING`.
2. **Dispatch** each fix task to a fresh `darwin-executor` with the owning task's context and the finding verbatim (tier per the escalation table — Fast owners go to High). Fix tasks that change behavior must update the proposal and the behavior deltas first; a fix may never edit a locked test.
3. **Gate** each fix task exactly like a wave (the `execute` skill's `references/gates.md` §3), commit it as `fix({scope}): evaluation — {summary}` (with the `Refs` trailer when there is a ticket), then run the post-wave suite.
4. **Re-dispatch the agent that reported the findings** (same model). Re-run the maintainer reviewer only if its findings were among them.
5. **Loop a maximum of 3 times.** After the third failed round, stop and escalate (Step 4).

Non-blocking findings never loop — they are recorded with the verdict.

When the user resolves a finding as "the test is wrong", follow the gates'
re-locking procedure; when as "the behavior is wrong", update the proposal and
re-apply the deltas.

### Step 4 — Verdict

Write the verdict into the Execution Log under exactly one of the headings
defined in the `plan` skill's `references/progress-file.md`, then commit the
progress file (`chore(darwin): record evaluation verdict`):

```markdown
### Evaluation — ✅ Approved
- Checker: <behavior table — ID | PASS/FAIL | evidence>
- Surviving mutants: <list or none>
- Maintainer: Verdict: approved
- Non-blocking notes: <list or none>
- Fix rounds: <0–3>
```

```markdown
### Evaluation — ❌ Escalated
- Unresolved blocking findings: <list, each with the agent that raised it>
- Fix rounds: 3
```

On `❌ Escalated`, tell the user:

> `❌ Evaluation escalated — the feature could not pass after 3 fix rounds.`
> Unresolved: [list]. Options: fix manually, change the plan, or accept with known issues.

If the user **accepts with known issues**, record that decision as the verdict
so finishing can proceed — replace the escalated entry with:

```markdown
### Evaluation — ✅ Approved
- Accepted by the user with known issues: <the unresolved findings, verbatim>
- Checker: <behavior table>
- Fix rounds: 3
```

If the user fixes things manually, re-run this skill from Step 1.

`finishing-development-branch` requires `### Evaluation — ✅ Approved`.

### Recording recurrences

For every finding tagged `(L-<n>)` — a mistake an existing lesson already
describes — append a `recurrence` event to this branch's lessons usage log, per
the `compound` skill's `references/lesson-format.md`. Recurring mistakes are the
strongest promotion signal.

## Manual Mode

When the user asks for a code review outside a Darwin feature (no progress
file, or an explicit "review this"):

- Dispatch only `darwin-maintainer-reviewer`, with the base ref the user names (default: the merge base with the main branch) and the proposal if one exists.
- Report its findings and verdict to the user. Do not create fix tasks or write a verdict heading — the user decides what to change.

## Orchestration Flow

```
all tasks COMPLETE + behavior deltas applied
    │
    ▼
┌──────────────────────────────┐
│  darwin-checker              │  runs suite, lint, typecheck,
│  (mutates, then restores)    │  mutation probes, the app
└──────────────┬───────────────┘
               ▼
       git status clean? ── no ──► restore, note it
               │
               ▼
┌──────────────────────────────┐
│  darwin-maintainer-reviewer  │  would maintainers merge it?
└──────────────┬───────────────┘
               │
   any blocking? ── yes ──► fix tasks → gate → re-dispatch reporter
               │                         (max 3 rounds, then ❌ Escalated)
               no
               ▼
   ### Evaluation — ✅ Approved
```

## Red Flags

**Never do these:**

| Red flag | Why it's dangerous |
|---|---|
| Run the checker and maintainer reviewer in parallel | The checker temporarily mutates source files; the reviewer would read mutants |
| Skip the tree check after the checker | A leftover mutant would be committed with the next fix |
| Review the code yourself | The orchestrator wrote or supervised the code; an independent fresh-context agent is the point |
| Accept a FAIL because "the code looks right" | The checker's evidence decides; argue with evidence or escalate |
| Edit a locked test in a fix task | That changes what "done" means without the user |
| Exceed 3 fix rounds without escalating | Infinite loops waste time — escalate to the user for a decision |

## Integration

- **Called by**: the `execute` skill (Execution Flow step 11); `resume` (finished plan without a verdict); the user (manual mode)
- **Uses**: `darwin-checker` and `darwin-maintainer-reviewer` agents; `darwin-executor` for fix tasks
- **References**: the `execute` skill's `references/model-selection.md` and `references/gates.md`; the `plan` skill's `references/progress-file.md` (verdict headings); the `compound` skill's `references/lesson-format.md` (recurrence events)
- **Pairs with**: `finishing-development-branch` skill (runs after `### Evaluation — ✅ Approved`)
