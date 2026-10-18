---
name: compound
description: >
  Capture reusable learnings from a completed execution cycle. Analyzes what was
  planned vs. what happened, identifies patterns, mistakes, decisions, and gotchas,
  writes them as lessons in .darwin/learnings/, and promotes often-used lessons into
  checks or retires irrelevant ones with the user's approval.
---

# Compound Learning

Capture knowledge gained during development so it compounds across sessions. After
an execution cycle completes, this skill analyzes what happened — evaluation
findings, escalations, red-test loops, user corrections, emergent patterns,
architectural decisions — and distills reusable insights into lessons. Lessons that
keep proving useful are turned into checks; lessons that keep proving irrelevant are
retired.

**Core principle**: only capture genuinely reusable insights, not one-off fixes.
A lesson earns its keep by being applied; a lesson applied often enough should
become a check, so nobody has to remember it.

**Format**: lesson files, usage logs, derived counts and lesson selection are defined
once in [references/lesson-format.md](references/lesson-format.md). Read it before
writing or counting anything.

## When This Skill Fires

- User says `/compound` or "capture learnings"
- Automatically at the end of a feature in execute mode, after the end-of-feature evaluation
- Suggested by the session-start hook when a `.pending-session` marker exists
- In **light capture mode** (see below), from `quick`, `systematic-debugging`, or when the user corrects the agent mid-task

## Constraints

- **Allowed**: Reading the progress file, git history, lessons and usage logs; writing new lesson files; appending usage events; editing a lesson's `status` / `promotedTo` lines; writing an approved check
- **Forbidden**: Writing a lesson without user approval; writing a check without user approval; deleting a lesson file; rewriting or deleting usage-log lines; editing another lesson's body
- Thresholds come from `.darwin/config.json` — `learnings.promoteAt` (default `3`) and `learnings.retireAfter` (default `10`), as defined in the `execute` skill's Darwin Config section

## Process

### Phase 0 — Migration (first run only)

Run this phase only when `.cursor/darwin-learnings/` exists. Otherwise skip to Phase 1.

1. **Create** `.darwin/learnings/` and `.darwin/learnings/usage/` if missing.
2. **Move** each lesson file `.cursor/darwin-learnings/*.md` to `.darwin/learnings/` (`git mv` when the file is tracked), keeping its file name.
3. **Convert** each moved file's frontmatter to the lesson format, using the matching entry in `.cursor/darwin-learnings/index.json` when there is one:
   - `files` → `scope` (from the file's frontmatter, else the index entry)
   - `summary` from the index entry; if the file has no index entry, use its `# Title`
   - assign `id`: `L-1`, `L-2`, … in file-name (date) order, continuing after any `L-<n>` already in `.darwin/learnings/`
   - `status: active`, `promotedTo: null`; keep `date`, `category`, `confidence` and `tags`
   - leave the body sections untouched
4. **Delete** `.cursor/darwin-learnings/index.json`.
5. **Clean up** the old directory: delete the legacy `.cursor/darwin-learnings/.pending-session` if present, then remove `.cursor/darwin-learnings/` if it is now empty. If anything else is left in it, leave it and list it.
6. **Ignore the marker**: ensure `.darwin/learnings/.pending-session` is in the project's `.gitignore`.
7. **Report** what moved:

```
Migrated [N] lessons from .cursor/darwin-learnings/ to .darwin/learnings/:
- L-1 — [summary] (scope: [..])
- ...
Removed index.json. Left behind: [files, or "nothing"].
```

Then continue with Phase 1.

### Phase 1 — Gather Context

Collect the raw material for analysis:

1. **Read `.darwin/darwin-progress.md`** — the plan, task states, execution log, and end-of-feature evaluation findings
2. **Run `git diff main...HEAD`** (or the appropriate base branch) — see actual code changes
3. **Run `git log --oneline main...HEAD`** — commits made during this execution
4. **Read this branch's usage log** `.darwin/learnings/usage/<branch-slug>.jsonl` (slug rule in lesson-format.md) — which lessons were delivered, applied, judged not relevant, or recurred
5. **Check for a `.pending-session` marker** (`.darwin/learnings/.pending-session`, or the legacy `.cursor/darwin-learnings/.pending-session`) — if present, this is a follow-up from an interrupted session

If none of sources 1–4 exist, run Phase 6 step 1 (delete the markers) so the session-start reminder doesn't repeat, then report:

```
No execution context found. Compound learning works best after completing
an execution cycle. Use /execute to implement a plan first.
```

Phases 3–5 (count, promote, retire) still apply in that case if `.darwin/learnings/usage/` has events — offer them: "No new context, but [N] lessons are due for promotion or retirement. Review them? (yes / no)".

### Phase 2 — Capture New Lessons

Compare what was planned vs. what happened. Look for:

| Signal | What it indicates |
|--------|-------------------|
| End-of-feature evaluation findings | A mistake or convention worth remembering |
| Review feedback that required code fixes | A mistake or convention worth remembering |
| Tasks that needed re-dispatch or escalation | A complexity that was underestimated |
| Red-test loops (a task cycling on failing tests) | A gotcha or a missing pattern |
| User corrections recorded in the log | A convention or decision the agent didn't know |
| Unexpected blockers in execution logs | A gotcha for future work in this area |
| Patterns that emerged across multiple tasks | A convention worth codifying |
| Architectural decisions made during execution | A decision that should be recorded |

**Check existing lessons first.** If a finding is a mistake an existing lesson already describes, it is a recurrence, not a new lesson: append a `recurrence` event for that lesson to this branch's usage log (unless one was already logged for the same task) and do not capture it again.

#### Filtering Criteria

Only capture learnings that are **reusable**. Skip:
- One-off typos or syntax errors
- Environment-specific issues (wrong Node version, missing env var)
- Changes that were simply implementing the plan as written

#### Categorization and Scope

Assign each learning a category (`pattern`, `mistake`, `decision`, `convention`, `gotcha` — defined in lesson-format.md) and a `scope`: the narrowest path prefixes or globs where it applies, taken from the files involved. A scope that is too wide gets the lesson delivered where it doesn't apply, and it retires.

#### Present for Approval

```
I identified [N] learnings from this execution:

1. [category] — [one-line summary] (scope: [..])
2. [category] — [one-line summary] (scope: [..])

Recurrences logged: [L-<n> — summary, or "none"]

Write these to .darwin/learnings/? (yes / edit / skip)
```

On **skip**, continue to Phase 3 — the user has seen the learnings and declined them.

#### Write Lessons

For each approved learning, create `.darwin/learnings/YYYY-MM-DD-<slug>.md` in the lesson format: next free `id`, `status: active`, `promotedTo: null`, and the What Happened / Learning / Evidence body. Write the `## Learning` section as guidance for the next agent working in this scope — it is what gets delivered.

**Create Directory**: if `.darwin/learnings/` does not exist, create it (and `usage/`), and ensure `.darwin/learnings/.pending-session` is in `.gitignore`. Lessons and usage logs are committed to git.

### Phase 3 — Count

Read **every** file in `.darwin/learnings/usage/` (all branches, not only this one) and compute `uses`, `recurrences` and `irrelevantStreak` for each lesson exactly as lesson-format.md defines. Report duplicate `id`s if you find any (handling is in lesson-format.md).

Only `active` lessons are candidates for Phases 4 and 5.

### Phase 4 — Promote

A lesson is due when `uses + recurrences ≥ learnings.promoteAt`. For each one, propose turning it into a check, choosing the **first** option that can express the lesson:

1. **A lint rule** in the project's existing linter config. Never add a new linter.
2. **A test** that fails when the lesson is violated.
3. **A hook** in the project's existing hook setup (e.g. pre-commit).
4. **A path-scoped rule**, written for **both hosts** (two files, because the formats differ):
   - Cursor — `.cursor/rules/<name>.mdc`:
     ```markdown
     ---
     description: [lesson summary]
     globs: src/scans/**,src/ui/dates.ts
     alwaysApply: false
     ---
     [the lesson's Learning section]
     ```
   - Claude Code — `.claude/rules/<name>.md`, with a `paths` list of globs (a path-scoped rule loads when Claude reads or edits a matching file):
     ```markdown
     ---
     paths:
       - "src/scans/**"
       - "src/ui/dates.ts"
     ---
     [the lesson's Learning section]
     ```
   - Turn each `scope` entry into a glob: a directory prefix `dir/` becomes `dir/**`; globs and exact paths stay as they are. Name both files `lesson-<id>-<slug>` so they are traceable.
   - Before writing the Claude Code file, verify the `.claude/rules/` `paths` format against the current Claude Code documentation; if it has changed, follow the docs and say so in the report.

Present all due lessons together:

```
[N] lessons have been used often enough to become checks:

1. L-12 — [summary] (uses 2, recurrences 1)
   Proposed: lint rule — [rule and config file]
2. L-4 — [summary] (uses 3, recurrences 0)
   Proposed: path-scoped rule — .cursor/rules/lesson-L-4-<slug>.mdc + .claude/rules/lesson-L-4-<slug>.md

Approve each: (1: yes / no / other check, 2: ...)
```

**The user approves each one.** On approval: write the check, run it once to confirm it passes on the current code (a lint rule or test that fails on current code means the code violates the lesson — report it, don't silently fix it), then set `status: promoted` and `promotedTo: <path of the check>` in the lesson's frontmatter. A promoted lesson is no longer delivered — the check enforces it now. A declined lesson stays `active`.

### Phase 5 — Retire

A lesson is retiring when `irrelevantStreak ≥ learnings.retireAfter`. List them:

```
[N] lessons were delivered [retireAfter]+ times in a row without applying:

- L-7 — [summary] (scope: [..], last applied: [date or "never"])

These will be marked retired unless you object. (ok / keep L-<n> ...)
```

Set `status: retired` on every listed lesson the user didn't keep. **Never delete a lesson file.** If the user keeps a lesson, suggest narrowing its `scope` — a wide scope is the usual cause.

### Phase 6 — Clean Up

1. **Delete the pending-session markers** on every exit path (captured, skipped, or no context): `.darwin/learnings/.pending-session`, and the legacy `.cursor/darwin-learnings/.pending-session` if present
2. Report what was captured, logged, promoted, and retired
3. If running within execute mode, return control — proceed to finishing

## Light Capture Mode

Invoked from `quick`, `systematic-debugging`, and mid-task user corrections when something went wrong — an escalation, a red-test loop, a user correction. **One question, not a ceremony.** Phases 0 and 3–5 do not run; the next full compound run handles counting, promotion and retirement.

1. **State the mistake in one line**, with the files involved.
2. **Match it against existing lessons**: `active` and `promoted` lessons whose `scope` matches those files (selection rules in lesson-format.md, without the cap) and whose Learning describes the same mistake.
   - **Match** → append a `recurrence` event to this branch's usage log (`task`: `quick`, `debugging`, or `correction`) and say so in one line: "Logged a recurrence of L-<n> — [summary]." Do not create a lesson. If the match is a `promoted` lesson, add: "Its check ([promotedTo]) did not catch this."
   - **No match** → ask the one question:
     ```
     Worth remembering? [category] — [one-line summary] (scope: [..]) (yes / edit / no)
     ```
     On yes, write the lesson as in Phase 2 (creating the directory and `.gitignore` entry if needed). On no, move on.
3. Return control to the calling skill. Do not touch the `.pending-session` markers.

Skip light capture entirely when the mistake fails the filtering criteria (a typo, an environment issue).

## Red Flags

| Red flag | Prevention |
|----------|------------|
| Capturing trivial learnings | Apply filtering criteria strictly |
| Writing lessons without user approval | Always present for approval first |
| Capturing a recurrence as a new lesson | Check existing lessons before capturing |
| Scope too wide ("**" by default) | Use the narrowest prefixes from the files involved |
| Writing a check without approval | Each promotion is approved individually |
| Deleting a lesson or rewriting a usage line | Lessons retire; logs are append-only |
| Counting from this branch's log only | Phase 3 reads every file in `usage/` |
| Capturing environment-specific issues | Filter out non-reusable items |
| Running without execution context | Check sources in Phase 1 |

## Integration

- **Called by**: Execute skill at the end of a feature (auto, after the evaluation), `/compound` (manual), session-start hook suggestion; light capture mode from `quick`, `systematic-debugging`, and user corrections
- **Reads**: `.darwin/darwin-progress.md`, git diff, git log, `.darwin/learnings/` (lessons and all usage logs), `.darwin/config.json`, the `.pending-session` markers
- **Produces**: lesson files in `.darwin/learnings/`, events in `.darwin/learnings/usage/<branch-slug>.jsonl`, approved checks (lint rule, test, hook, or path-scoped rules for both hosts), `status` / `promotedTo` edits
- **Consumed by**: `research`, `plan`, and `execute` (and the agents execute dispatches), which read and select lessons per [references/lesson-format.md](references/lesson-format.md)
