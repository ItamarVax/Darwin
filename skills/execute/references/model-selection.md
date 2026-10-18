# Model Selection

This file is the single tier→model table for Darwin's subagent dispatches —
executors (the `execute` skill) and the end-of-feature evaluation agents (the
`reviewing-implementation` skill). Both skills read the active profile from
`.darwin/config.json` (see the `execute` skill's Darwin Config section; default
`balanced`).

## Executors

**The tier comes from the plan.** Each task detail block carries a
`Tier: Fast | High` field recorded by the planner, who had the most context for
the decision. Use it directly — do not re-derive tiers per wave. Only two
overrides are allowed:

- **Upgrade** Fast → High when the escalation rules below apply (red tests, missing context, a blocker) or when a High-tier signal is plainly present that the plan missed.
- A task with **no `Tier` field** (legacy plan): evaluate it against the High-tier signals below, and record the decision in the decision log.

Never downgrade High → Fast. Task 0 is always High.

### Per-Call Parameter Mapping

The `model` parameter passed to the `Task`/`Agent` tool depends on the host and
the active profile. Cursor exposes only `"fast"`/omit, so profiles differentiate
on Claude Code only:

| Tier | Claude Code (economy) | Claude Code (balanced/quality) | Cursor (all profiles) |
|------|----------------------|-------------------------------|----------------------|
| Fast | `model: "haiku"` | `model: "sonnet"` | `model: "fast"` |
| High | `model: "sonnet"` | `model: "opus"` | omit `model` |

### High-Tier Signals

Use these to validate a plan-recorded tier (upgrade-only) or to derive a tier
when the plan omits it. The list differs by host: Claude Code's Fast tier
(Sonnet) handles multi-file coordination comfortably, while Cursor's Fast tier
is a smaller model where cross-module work still warrants escalation. Read only
the section matching the host you are running on.

#### Claude Code

A task is high regardless of file count if any of these are true:
- Executor must make design decisions not resolved in the plan
- Task requires writing or editing prompts, user-facing copy, or agent instructions
- Task requirements are ambiguous
- The task has neither tests nor `Exact` blocks to work against (reduced or legacy mode) and touches more than one file

#### Cursor

A task is high regardless of file count if any of these are true:
- Executor must make design decisions not resolved in the plan
- Task involves multi-file coordination with cross-module logic
- Task requires writing or editing prompts, user-facing copy, or agent instructions
- Task requirements are ambiguous
- The task has neither tests nor `Exact` blocks to work against (reduced or legacy mode)

### Escalation on Re-dispatch

| Previous outcome | Original tier | Re-dispatch |
|------------------|---------------|-------------|
| Tests still red at the gate (first time) | any | Same tier, fresh executor, with the failure output |
| Tests still red at the gate (second time) | Fast | High, fresh executor, with both failure outputs |
| Tests still red at the gate (second time) | High | Escalate to the user |
| `NEEDS_CONTEXT` | Fast | High (add context) |
| `NEEDS_CONTEXT` | High | High (add context) |
| `BLOCKED` | Fast | High |
| `BLOCKED` | High | Escalate to the user if second failure |
| `BLOCKED: test defect` | any | Ask the user — fix the code, the test, or the behavior — then re-lock and re-dispatch |
| Evaluation finding (fix task) | Fast | High |

### Decision Log

Before dispatching each wave, record in the execution log:

```text
### Wave [N] — Model Selection
| Task | Tier | Executor | Justification |
|------|------|----------|---------------|
| 1    | Fast | subagent | Tests from Task 0, 2 files, no judgment |
```

## Evaluation Agents

| Dispatch | Claude Code (economy) | Claude Code (balanced) | Claude Code (quality) | Cursor (all profiles) |
|----------|----------------------|------------------------|-----------------------|----------------------|
| `darwin-checker` | `model: "sonnet"` | `model: "sonnet"` | `model: "opus"` | omit `model` |
| `darwin-maintainer-reviewer` | `model: "sonnet"` | `model: "opus"` | `model: "opus"` | omit `model` |

When re-dispatching an evaluation agent after a fix loop, keep the same model.
