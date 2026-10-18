# Darwin

AI development workflow that learns and adapts to your codebase. Darwin keeps a living description of what your product does, makes tests the contract for every change, proves "done" by running things instead of trusting the agent, and evolves from its own mistakes.

## Why Darwin?

AI coding agents have four failure modes:

- **Memory loss** — every session starts from zero. Conventions get re-learned, then re-violated.
- **Scope creep** — ask for a fix, get a refactor of three adjacent files you didn't want touched.
- **Claimed, not proven** — the agent says it's done; nobody ran anything. A self-graded "looks good" is not evidence.
- **Docs that rot** — whatever spec existed described the plan, not the product, and nobody updated it after the merge.

Darwin answers each one with explicit structure rather than hope:

- **Tests are the contract** — for a feature, the plan writes the tests first (Task 0) and locks them. Executors — cheap, fast models running in parallel — fill in code until those tests pass. An executor cannot change what "done" means.
- **Proof, not claims** — every task is gated by commands the orchestrator runs itself. One evaluation at the end runs the suite, probes the tests with deliberate mutations, exercises the app, and asks whether your maintainers would merge it.
- **Living behaviors** — `.darwin/behaviors/` describes what the product does, one file per capability, each requirement linked to the tests that prove it. Every change updates it, and a strict drift check makes sure it does.
- **Process sized to the task** — a one-line fix doesn't go through the full chain. Darwin picks a track (direct, quick, bugfix, feature) and you can override it.
- **Evolution** — lessons are captured wherever something went wrong, delivered to the agents working on those files, and counted. Lessons that keep proving useful are promoted into real checks (with your approval); ones that never matter are retired.
- **Clean, resumable history** — per-task conventional commits, git-worktree isolation per feature, and `/resume` for interrupted runs.

## Darwin vs. other spec-driven plugins

Plugins like [Superpowers](https://github.com/obra/superpowers) give agents a library of composable skills they can reach for as situations arise. Darwin takes a more structured stance: a five-mode workflow (Research → Innovate → Plan → Execute → Review) with hard transitions between modes and a constitutional `[MODE: ...]` declaration that opens every reply, so the agent's current state is always visible to you.

What's distinctive about Darwin:

- **Dual-host, single repo** — first-class plugin in both Cursor and Claude Code. The same skills, agents, and hooks load in both IDEs from one install.
- **Spec-anchored, not spec-first** — most spec-driven tools write a spec per change and throw it away. Darwin's behavior files live on: each change proposal lists behavior deltas (added, modified, removed), and finishing the branch leaves the behavior files describing the product as it now is.
- **Explicit mode contract** — every response begins with `[MODE: ...]`. No guessing whether the agent is still researching or has started editing.
- **Onboarding tailors the framework to your codebase** — `/onboarding` records your test and lint commands, sets up a test suite if you have none, captures your core capabilities as behavior files, and generates project rules plus project-specific skills and agents.
- **A learning loop that is measured** — lesson usage is logged per branch, so promotion and retirement are based on how often a lesson actually mattered.

## What You Get

- **Four tracks** — `direct` (one-sentence changes), `quick` (small, fully described changes), `bugfix` (root cause, failing regression test, fix), and `feature` (the full chain). Darwin states the track; you can override it.
- **Five modes with strict boundaries** — Research, Innovate, Plan, Execute, Review. Each mode suggests the next; innovate is skipped when there is one obvious approach.
- **Change proposals you can review in two minutes** — the main thing you approve for a feature is a short proposal: why, the approach, what's out of scope, and the behavior changes with how each will be verified.
- **Tests-first plans** — Task 0 writes a code skeleton and every test change; the red check confirms the new tests fail for the right reason; the test files are hash-locked. Exact implementation code appears in the plan only where the exact text matters (schemas, migrations, public APIs, prompts, tricky algorithms).
- **Cheap parallel executors** — fill-in tasks run on fast models in parallel; a task whose tests stay red escalates to a stronger model, then to you.
- **Mechanical gates** — after every wave the orchestrator re-runs each task's tests, verifies the test lock, checks the working tree, commits per task, and runs the full suite.
- **One evaluation at the end** — `darwin-checker` runs the suite, lint, typecheck, mutation probes on changed lines, and the app, then grades every behavior ID PASS/FAIL with evidence. `darwin-maintainer-reviewer` asks whether this repo's maintainers would merge it — conventions, scope creep, dead code, test quality, risky patterns; never style.
- **Behavior files and a strict drift check** — `scripts/behavior-check.sh` fails a change that touches covered code without updating its behavior file or declaring `Behavior-Change: none (<capability>) — <reason>`. It runs before every direct, quick, bugfix, and `/git-ship` commit, after a feature's behavior changes are applied, and at finishing.
- **Evolving learnings** — capture everywhere, scoped delivery, usage counting, promotion to checks with approval, retirement.
- **Per-task conventional commits** and **git-worktree isolation** — approving a plan creates a feature worktree in `.worktrees/`; execution runs there, so your main checkout stays clean.
- **Root-cause-first debugging** — `systematic-debugging` enforces a four-phase process and a failing regression test before any fix.
- **Session resumption** — `/resume` picks up interrupted executions, re-verifying the test lock first.
- **Cost-aware execution** — research runs on a Sonnet subagent; each plan task carries a model tier decided at plan time; a per-project cost profile tunes model routing and the checker's depth — see [Configuration](#configuration-darwinconfigjson).
- **Bundled MCP servers** — Atlassian and DeepWiki, configured out of the box for external research.
- **Lifecycle hooks** — session-start reminders (onboarding, `/resume`, `/compound`, Darwin 5 setup), session-end bookkeeping, and a shell-exec safety blocklist.

Darwin never pushes on its own. Pushing happens only when you run `/git-ship` or choose "push and create pull/merge request" when finishing a branch.

## Installation

Darwin installs as a first-class plugin in both Cursor and Claude Code.
The same `skills/` and `agents/` trees serve both hosts.

### Cursor (IDE)

1. Clone this repo into your Cursor plugins directory:

```bash
git clone https://github.com/ItamarVax/darwin.git ~/.cursor/plugins/local/darwin
```

2. Restart Cursor (or run `Developer: Reload Window` from the command palette).

3. Verify: Open Cursor Settings → Rules. You should see **Darwin Framework - Core** listed under plugin rules.

### Claude Code

Inside any Claude Code session, register the GitHub repo as a plugin marketplace and install:

```
/plugin marketplace add ItamarVax/darwin
/plugin install darwin@darwin
```

The full URL (`https://github.com/ItamarVax/darwin.git`) and the SSH form
(`git@github.com:ItamarVax/darwin.git`) also work. For local
development against an unpushed checkout, point the marketplace at an
absolute path instead, e.g. `/plugin marketplace add /Users/you/.cursor/plugins/local/darwin`.

Restart the session. Verify with `/` — you should see `/darwin:research`,
`/darwin:plan`, `/darwin:using-darwin`, etc. The `using-darwin` skill
auto-fires on Darwin keywords and installs the `[MODE: ...]` declaration
contract; on Cursor, the same contract loads via `rules/framework.mdc`.

### Copy into project (alternative, Cursor only)

Copy the contents of this repo into your project's `.cursor/` directory:

```bash
cp -r rules/ agents/ skills/ /path/to/your-project/.cursor/
```

### Cursor CLI Support (optional)

The Cursor IDE Agent loads Darwin's rules, skills, and agents
automatically via the plugin system. The `cursor-agent` CLI does not —
it only reads user-scoped (`~/.cursor/skills/`, `~/.cursor/agents/`) and
project-scoped (`<project>/.cursor/rules/`) resources.

If you use Darwin from the Cursor CLI, run the setup scripts described
in [`CLI-SUPPORT.md`](./CLI-SUPPORT.md). Claude Code does not need this
step — its plugin system loads everything from the marketplace install.

### Future: Cursor Plugin Marketplace

Cursor Marketplace distribution is planned once Cursor Team Marketplaces
support GitHub repositories.

## Getting Started

After installation, run the onboarding skill in any project:

```
Set up Darwin for this project
```

The onboarding skill will:
1. Scan your project for existing AI configuration and conventions
2. Ask which team/area you work in (if applicable)
3. Detect your test, lint, typecheck, and run commands and save them to `.darwin/config.json`
4. Offer to set up a minimal test suite if the project has none (it asks before installing anything)
5. Generate project-specific rules (`project-context.mdc`, `code-quality-standards.mdc`, `development-commands.mdc`, …)
6. Propose project-specific skills and agents from what it found
7. Let you pick a few core capabilities and draft a behavior file for each (marked `observed` until you confirm them with `/behaviors confirm`)

Commit `.cursor/`, `.claude/`, `CLAUDE.md`, `.darwin/config.json`, and `.darwin/behaviors/`.

### Upgrading from Darwin 4

- Run onboarding again and choose **"Set up Darwin 5 (commands, tests, behaviors)"** — it records your commands, offers test setup, and captures initial behavior files without touching your other rules. The session-start hook suggests this once per repository.
- Plans already in flight keep working: execute runs a Darwin 4 progress file in **legacy mode** (no Task 0, gates on each task's acceptance checks, the checker grades acceptance criteria).
- Learnings migrate automatically the first time `/compound` runs: `.cursor/darwin-learnings/` moves to `.darwin/learnings/`, and `index.json` is replaced by lesson frontmatter.
- Archived plans under `.darwin/plans/` stay where they are; new archives go to `.darwin/archive/`.

## Usage

### Choosing a track

| Track | When | Flow |
|-------|------|------|
| direct | The diff fits in one sentence; obvious location | `/quick` — edit, run tests, drift check, commit |
| quick | Small, clear, fully describable before starting | `/quick` — mini-plan, edit, tests, drift check, commit |
| bugfix | Something is broken | `/systematic-debugging` — root cause, failing regression test, fix |
| feature | New or changed behavior, multi-file and uncertain, unfamiliar code | the full chain below |

Darwin states the track in one line at the start; tell it if you want a different one.

### Mode Skills

| Skill | Invoke | Purpose |
|-------|--------|---------|
| Research | `/research` | Understand code: reads behavior files first, reports how the area is tested and which lessons apply |
| Innovate | `/innovate` | Compare approaches; ends by writing the change proposal (`.darwin/proposal.md`) |
| Plan | `/plan` | Task 0 (skeleton + tests), tasks covering every behavior ID, worktree and baseline test run |
| Execute | `/execute` | Wave 0, parallel executors, mechanical gates, behavior deltas, end-of-feature evaluation |
| Review | `/review` | Validate implementation |

### Utility Skills

| Skill | Invoke | Purpose |
|-------|--------|---------|
| Quick | `/quick` | Direct and quick tracks: one-line and small changes, verified and drift-checked in one pass |
| Behaviors | `/behaviors` | Capture a capability's behavior file, confirm observed requirements, answer "what does X do?" |
| Systematic Debugging | `/systematic-debugging` | Root cause first, then a failing regression test, then the fix |
| Refactor | `/refactor` | Analyze codebase for improvement opportunities |
| Compound | `/compound` | Capture lessons, count their use, propose promotions and retirements |
| Resume | `/resume` | Resume an interrupted execution session |
| Git Ship | `/git-ship` | Commit (drift-checked) → push → PR, when you ask for it |
| Git Cleanup | `/git-cleanup` | Clean up branches and worktrees |
| Fix All | `/fix-all` | Run project quality checks and auto-fix |
| Create Skill | `/create-skill` | Author a new project skill with proper structure |
| Create Agent | `/create-agent` | Author a new custom subagent |

On Claude Code, skills are namespaced — invoke them as `/darwin:research`, `/darwin:quick`, etc.

### The feature flow

```
/research → /innovate → /plan → [approve] → cd <worktree> → /execute → (evaluation) → done
```

1. **Research** reads the behavior files covering the area, then the code, and reports how it is tested.
2. **Innovate** compares approaches and writes the **change proposal** — the behavior changes (`ADDED` / `MODIFIED` / `REMOVED` / `NEW CAPABILITY`), each with how it will be verified. You approve the proposal. (With one obvious approach, research goes straight to plan, and plan writes the proposal.)
3. **Plan** writes Task 0 — a skeleton for new code plus every test change — and tasks that each cover behavior IDs. If the project has no test command, plan offers test setup first; if you decline, the plan runs in **reduced mode** (acceptance checks instead of tests). Approving the plan creates a worktree under `.worktrees/` on a `feat/<slug>` branch, records a baseline test run, commits the plan and the proposal there, and drops a `.darwin/active-worktree` breadcrumb so `/resume` can find it. **Move into the worktree (`cd <worktree_path>`) before running `/execute`.**
4. **Execute** runs Task 0, confirms the new tests fail for the right reason (the red check), and hash-locks the test files. Then waves of executors fill in code, in parallel where tasks are independent. After each wave the orchestrator re-runs every task's tests, verifies the lock, commits each task, and runs the full suite. Finally it applies the behavior changes to `.darwin/behaviors/`.
5. **Evaluation** — the checker runs everything and grades each behavior ID; the maintainer reviewer reads the whole diff. Blocking findings become fix tasks (up to 3 rounds, then you decide).
6. **Compound** captures lessons; **finishing** runs the drift check, archives the change to `.darwin/archive/<slug>/`, and offers merge, merge request (with behavior changes and evidence in the description), keep, or discard.

**Starting from a ticket**: `/research PROJ-123` (or a Jira `/browse/` URL) fetches the ticket through the bundled Atlassian MCP and carries it through the run — its acceptance criteria become draft behavior changes, the branch is named `feat/PROJ-123-<slug>` (`fix/` for bugs), every task commit gets a `Refs: PROJ-123` trailer, and the merge request is titled `PROJ-123: <plan title>`. `/plan PROJ-123` and `/quick PROJ-123` work the same way. Darwin never writes back to Jira.

## Behaviors

A behavior file (`.darwin/behaviors/<capability>.md`) describes what one area of the product does — never how it is built:

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
```

- IDs are permanent; removed requirements stay as tombstones so an ID is never reused.
- `observed` requirements were recorded from existing code and may encode bugs; `intended` ones were decided or confirmed by a person and must point at a test.
- Coverage grows where work happens: onboarding captures a few core capabilities, and a feature that touches uncovered code declares a new capability in its proposal.

**The drift check** (`scripts/behavior-check.sh`) fails when covered code changed without its behavior file being updated, unless a commit on the branch carries the trailer:

```
Behavior-Change: none (export) — internal restructure, same output
```

It also checks that every test pointer resolves and every ID is unique. On a feature branch (one with a change proposal), changed code that no behavior file covers is an error; on direct and quick changes it is a warning. Test files, docs, and Darwin's own files are never treated as product code. The full format is in the `behaviors` skill.

## Learnings

Lessons live in `.darwin/learnings/` (one file each, committed) and evolve:

- **Captured everywhere** — after a feature, and in light form after a quick change, a bugfix, or a correction from you, whenever something went wrong.
- **Delivered where they apply** — each lesson has a `scope` of paths; executors, the checker, and the maintainer reviewer get the lessons for the files they touch.
- **Counted** — agents report whether each delivered lesson applied; checker and maintainer findings that repeat a known lesson count as recurrences. Usage is logged per branch in `.darwin/learnings/usage/`, so parallel branches never conflict.
- **Promoted** — once a lesson has been used often enough (`learnings.promoteAt`, default 3), `/compound` proposes turning it into a real check: a lint rule, a test, a hook, or a path-scoped rule for both hosts. You approve each one.
- **Retired** — a lesson that is repeatedly irrelevant (`learnings.retireAfter`, default 10 deliveries) is retired unless you object. Nothing is deleted.

## Configuration (`.darwin/config.json`)

Onboarding writes this file; commit it. Every key is optional.

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
  "behaviors": { "enabled": true, "strictUncovered": false, "ignore": [] },
  "learnings": { "promoteAt": 3, "retireAfter": 10 },
  "checker": { "mutationProbes": true, "exerciseApp": "auto" },
  "execute": { "serialWaves": false }
}
```

A missing `commands.test` means the project has no test setup — feature and bugfix work offer to set one up. The full key reference is the `execute` skill's Darwin Config section.

### Cost Profiles

| Profile | Executor (Fast / High tier) | Checker | Maintainer review |
|---------|-----------------------------|---------|-------------------|
| `economy` | Haiku / Sonnet | Sonnet, no mutation probes | Sonnet |
| `balanced` (default) | Sonnet / Opus | Sonnet, mutation probes | Opus |
| `quality` | Sonnet / Opus | Opus, more mutants, always exercises the app | Opus |

Model routing differentiates on Claude Code; Cursor exposes only a `fast` tier, so profiles mostly change the checker's depth there. Each task's tier (`Fast`/`High`) is recorded in the plan by the planner, where the most context exists for the decision.

Note (Claude Code): the `CLAUDE_CODE_SUBAGENT_MODEL` environment variable silently overrides all agent model settings — unset it if Darwin's routing seems ignored.

## Project-Specific Configuration

Darwin separates generic workflow rules from project-specific configuration. After onboarding, your project's `.cursor/rules/` will contain:

| File | Purpose |
|------|---------|
| `project-context.mdc` | Conventions, gotchas, and project-specific safety rules |
| `code-quality-standards.mdc` | Language-specific quality rules (linting, formatting, imports) |
| `development-commands.mdc` | Project commands (kept in sync with `.darwin/config.json`) |
| `glossary.mdc` | Domain terminology |

Onboarding deliberately does not generate architecture or module overviews: agents explore code themselves, and generated overviews go stale while costing context in every session. What lives where is answered by the behavior files instead.

### Research Artifact

When you fire `/research`, Darwin dispatches a Sonnet-backed `darwin-researcher` subagent that performs the codebase investigation in isolated context and writes its findings to `.cursor/darwin-research.md`. This file is the active research artifact — overwritten on each `/research` run, never archived. The `innovate` and `plan` skills read it automatically when present.

### The `.darwin/` Directory

| Path | Where | What |
|------|-------|------|
| `.darwin/config.json` | committed | Commands, profile, and settings (see above) |
| `.darwin/behaviors/` | committed | Behavior files, one per capability |
| `.darwin/learnings/` | committed | Lessons; `usage/*.jsonl` holds per-branch usage logs |
| `.darwin/proposal.md` | main checkout, then the feature worktree | The active change proposal, committed with the plan |
| `.darwin/darwin-progress.md` | inside the feature worktree | The active plan + execution log, committed on the feature branch |
| `.darwin/active-worktree` | main checkout root (gitignored) | Breadcrumb pointing at the active worktree, cleared when the branch is merged or discarded |
| `.darwin/archive/<slug>/` | committed | `plan.md` and `proposal.md` of finished changes — a human-readable record; Darwin never reads it |
| `.darwin/plans/` | committed | Darwin 4 plan archives, left as they were |

## Architecture

```
darwin/
├── .cursor-plugin/
│   └── plugin.json              # Cursor plugin manifest
├── .claude-plugin/
│   ├── plugin.json              # Claude Code plugin manifest
│   └── marketplace.json         # Claude Code marketplace listing
├── mcp.json                     # MCP servers (read by Cursor)
├── .mcp.json                    # MCP servers (read by Claude Code) — keep in sync with mcp.json
├── hooks/                       # Command hooks
│   ├── hooks.json               # Claude Code event names
│   ├── hooks-cursor.json        # Cursor event names
│   ├── test-hooks.sh            # Hook regression tests (both hosts)
│   └── *.sh                     # Hook scripts (platform-detect via lib.sh)
├── rules/
│   └── framework.mdc            # Core framework for Cursor (mirrored in skills/using-darwin/ for Claude)
├── agents/
│   ├── darwin-researcher.md           # Research subagent (writes .cursor/darwin-research.md)
│   ├── darwin-executor.md             # Fills in code against locked tests
│   ├── darwin-checker.md              # End-of-feature checker: runs everything, grades behavior IDs
│   └── darwin-maintainer-reviewer.md  # End-of-feature review: would maintainers merge it?
├── scripts/
│   ├── behavior-check.sh         # Strict drift check for behavior files
│   ├── archive-change.sh         # Archives a finished change to .darwin/archive/<slug>/
│   ├── test-scripts.sh           # Script regression tests
│   └── cli-*.sh                  # Cursor CLI symlink helpers (see CLI-SUPPORT.md)
└── skills/
    ├── using-darwin/             # Constitution for Claude Code (mirrors rules/framework.mdc)
    ├── research/                 # RESEARCH mode
    ├── innovate/                 # INNOVATE mode (writes the change proposal)
    ├── plan/                     # PLAN mode (progress-file schema in references/)
    ├── execute/                  # EXECUTE mode (config contract; gates and model table in references/)
    ├── review/                   # REVIEW mode
    ├── quick/                    # Direct and quick tracks
    ├── behaviors/                # Behavior files (formats in references/)
    ├── refactor/                 # Codebase analysis
    ├── compound/                 # Learnings (lesson format in references/)
    ├── resume/                   # Session resumption
    ├── git-ship/                 # Commit → push → PR, on request
    ├── git-cleanup/              # Branch cleanup
    ├── fix-all/                  # Quality checks
    ├── using-git-worktrees/      # Worktree isolation
    ├── reviewing-implementation/ # End-of-feature evaluation
    ├── finishing-development-branch/ # Drift check, archive, integration
    ├── systematic-debugging/     # Root-cause debugging, regression test first
    ├── create-skill/             # Skill-authoring guide
    ├── create-agent/             # Subagent-authoring guide
    └── onboarding/               # Project setup (templates and test setup in references/)
```

## License

MIT
