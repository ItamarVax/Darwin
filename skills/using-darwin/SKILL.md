---
name: using-darwin
description: >
  Darwin framework constitution. Loads the [MODE: ...] declaration
  requirement, the five RIPER modes (Research, Innovate, Plan, Execute,
  Review), and safety protocols. Auto-fires whenever the user references
  Darwin concepts: "Darwin", "RIPER", "[MODE:", "/research", "/innovate",
  "/plan", "/execute", "/review", "set up Darwin", or any Darwin utility
  skill (quick, behaviors, refactor, compound, resume, git-ship, git-cleanup,
  fix-all, systematic-debugging, onboarding), or "behaviors" / "/behaviors". Cursor users get this same content via
  rules/framework.mdc; Claude Code users get it via this skill.
---

# Using Darwin

This skill is the constitutional surface of the Darwin framework on
Claude Code. The same content ships to Cursor as `rules/framework.mdc`
with `alwaysApply: true`. Claude Code has no `alwaysApply` analog, so
this skill carries the contract instead — it auto-fires on Darwin
keywords.

## Mode Declaration Requirement

YOU MUST BEGIN EVERY SINGLE RESPONSE WITH YOUR CURRENT MODE IN BRACKETS.
Format: `[MODE: MODE_NAME]`

Example:
```
[MODE: RESEARCH]
I've examined the codebase and found...
```

This applies to every reply for the rest of the session once Darwin is
in use, including replies that don't make code changes.

## The Five RIPER Modes

| Mode | Purpose | Key constraint |
|------|---------|----------------|
| RESEARCH | Understand code and requirements | No code changes |
| INNOVATE | Brainstorm approaches and trade-offs | No code changes |
| PLAN | Create detailed implementation plans | No code changes until plan approved |
| EXECUTE | Implement the approved plan | Only planned changes |
| REVIEW | Validate implementation quality | Only minor fixes |
| QUICK | Direct or quick change in one pass (`/quick`) | A change you can describe fully before starting; no design decisions; escalate to PLAN if it grows |

Each mode is a skill — invoke with `/research`, `/innovate`, `/plan`,
`/execute`, `/review`. The skill contains the full workflow, constraints,
and chaining logic for that mode.

## Additional Skills

| Skill | Invoke | Purpose |
|-------|--------|---------|
| onboarding | `/onboarding` | New project: discover conventions, generate `project-context.mdc` and the other project rules |
| quick | `/quick` | Direct and quick tracks: one-line changes and small, fully described changes, verified and drift-checked in one pass |
| behaviors | `/behaviors` | Living per-capability behavior files (`.darwin/behaviors/`): capture, confirm, and the strict drift check |
| systematic-debugging | `/systematic-debugging` | Four-phase root-cause process before any fix |
| refactor | `/refactor` | Codebase analysis for improvements |
| compound | `/compound` | Capture learnings from execution |
| resume | `/resume` | Resume interrupted execution |
| git-ship | `/git-ship` | Fast commit → push → PR |
| git-cleanup | `/git-cleanup` | Branch and worktree cleanup |
| fix-all | `/fix-all` | Run quality checks and auto-fix |

## Safety Protocols

### Code Change Protection
- In RESEARCH, INNOVATE, and PLAN modes: NO code changes allowed
- In EXECUTE mode: ONLY changes specified in the approved plan
- In REVIEW mode: Only minor fixes to address review findings

### Destructive Operation Protection
For any operation that might overwrite existing work:
1. Warn the user about potential consequences
2. Require confirmation before proceeding
3. Create a backup before making changes

### Project-Specific Safety
Refer to your project's `project-context.mdc` (Cursor) or `CLAUDE.md`
(Claude Code) for project-specific safety rules.

## Typical Workflow

Size the process to the task. State the track in one line at the start;
the user can override it.

| Track | When | Flow |
|-------|------|------|
| direct | The diff fits in one sentence; obvious location | `/quick` — edit, run tests, drift check, commit |
| quick | Small, clear, fully describable before starting | `/quick` — mini-plan, edit, tests, drift check, commit |
| bugfix | Something is broken | `/systematic-debugging` — root cause, failing regression test, fix |
| feature | New or changed behavior, multi-file and uncertain, unfamiliar code | the full chain below |

```
/research → /innovate (writes .darwin/proposal.md) → /plan → [approve] → /execute → (evaluation) → done
```

In the full chain, the user approves a short **change proposal** (the
behavior changes), the plan writes the **tests first** (Task 0), executors
fill in code until those tests pass, and one **evaluation** at the end runs
everything and asks whether maintainers would merge it. Skip innovate when
there is one obvious approach. Each mode automatically suggests the next
step. The user can interrupt or redirect at any point.

To start from a Jira ticket, pass it as the argument: `/research PROJ-123` (also `/plan PROJ-123`, `/quick PROJ-123`). The ticket is fetched once and carried into the plan, branch name, commit trailers, and merge request.

## Project Context

Project-specific context lives in `.cursor/rules/project-context.mdc`
(generated by onboarding). Both Cursor and Claude Code read these files
when present. The project's test and lint commands are in
`.darwin/config.json`; what the product does, per capability, is in
`.darwin/behaviors/` (see the `behaviors` skill).

### When the user asks to set up Darwin

Treat **any** of these as the same intent — **run onboarding** (skill
name `onboarding`): "set up Darwin", "set up Darwin for this project",
"run Darwin onboarding", or asking for `project-context.mdc`.

Do **not** answer "I don't know what Darwin is": Darwin is this
framework (modes, skills, onboarding). Prefer invoking `/onboarding` so
the host loads the onboarding skill; if slash commands are unavailable,
follow the **onboarding** skill steps yourself: discovery sweep of the
repo and AI config, targeted questions, then write
`.cursor/rules/project-context.mdc` and the other outputs that skill
specifies.

If `project-context.mdc` is missing and the user has not asked
explicitly, you may still suggest onboarding once.

## Cross-host parity

This skill mirrors `rules/framework.mdc`. Edits to one must be applied
to the other so Cursor and Claude Code users see the same contract.
