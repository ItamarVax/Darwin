# Lesson Format

This file is the single definition of Darwin's learnings storage: lesson files, usage logs, the counts derived from them, and how lessons are selected for a set of files. `compound` writes lessons; research, plan, execute and the agents read them. Everyone follows this definition.

**Why this shape.** Nothing here is a shared mutable file. Lessons are new files, usage logs are one append-only file per branch, and counts are computed on demand. Two branches in flight never conflict on learnings at merge.

## Layout

```
.darwin/learnings/
├── <YYYY-MM-DD>-<slug>.md        # one lesson per file (committed)
├── usage/
│   └── <branch-slug>.jsonl       # one append-only event log per branch (committed)
└── .pending-session              # session marker written by the hooks (git-ignored)
```

`.darwin/learnings/.pending-session` must be listed in the project's `.gitignore`. Whoever creates `.darwin/learnings/` adds it.

## Lesson Files

Path: `.darwin/learnings/<YYYY-MM-DD>-<slug>.md`. The date is the capture date; the slug is a short kebab-case form of the summary.

```markdown
---
id: L-12
date: "2026-10-18"
category: gotcha
summary: Scan API returns UTC; convert before display
scope: [src/scans/, src/ui/dates.ts]
status: active
promotedTo: null
confidence: high
---

# Scan API timestamps are UTC

## What Happened
[Brief description]

## Learning
[The reusable insight, written as guidance for the next agent working in this scope]

## Evidence
[Code references, review feedback, test results, or the user's correction]
```

| Field | Values | Meaning |
|-------|--------|---------|
| `id` | `L-<n>` | Stable identifier. Usage events refer to it. A new lesson takes the next free number: the highest `L-<n>` across `.darwin/learnings/*.md`, plus one |
| `date` | `"YYYY-MM-DD"` | Capture date (matches the file name) |
| `category` | `pattern` \| `mistake` \| `decision` \| `convention` \| `gotcha` | See below |
| `summary` | one line | What a reader needs to know without opening the file. Shown in prompts and to the user |
| `scope` | list of path prefixes or globs | The files this lesson applies to. Never empty — a lesson about the whole repo uses `["**"]`, sparingly |
| `status` | `active` \| `promoted` \| `retired` | Only `active` lessons are delivered |
| `promotedTo` | path or `null` | The check that now enforces the lesson. Set together with `status: promoted` |
| `confidence` | `high` \| `medium` \| `low` | How sure the capture was |

Optional: `tags: [..]` for human scanning. Nothing reads it.

**Categories:**
- **pattern** — a reusable approach that worked well
- **mistake** — something that went wrong and how to avoid it
- **decision** — an architectural or design choice with rationale
- **convention** — a project convention discovered or established
- **gotcha** — a non-obvious trap or constraint

**Edits after capture.** Lesson files are append-only as new files. The only later edits are the `status` and `promotedTo` lines. Nothing is deleted — a lesson that stops mattering becomes `retired`.

**Duplicate ids.** Two branches that each capture a lesson can both take the same next number. When `compound` finds two files with the same `id`, it reports them and, with the user's approval, gives the later file (by `date`, then file name) the next free number. Events logged before the renumber stay with the original id.

## Usage Logs

Path: `.darwin/learnings/usage/<branch-slug>.jsonl`. The branch slug is the current branch with a leading `<type>/` prefix removed, lowercased, and every run of non-alphanumeric characters replaced by `-` (the same rule as `scripts/archive-change.sh`; `feat/darwin-5` → `darwin-5`). On `main`, `master` or a detached HEAD, use `main`, `master` or `detached`.

One JSON object per line, appended, never rewritten:

```json
{"lesson":"L-12","event":"delivered","task":"2.3","date":"2026-10-18"}
{"lesson":"L-12","event":"applied","task":"2.3","date":"2026-10-18"}
{"lesson":"L-7","event":"not-relevant","task":"2.4","date":"2026-10-18"}
{"lesson":"L-3","event":"recurrence","task":"quick","date":"2026-10-19"}
```

| Field | Value |
|-------|-------|
| `lesson` | The lesson's `id` |
| `event` | Exactly one of `delivered`, `applied`, `not-relevant`, `recurrence` |
| `task` | The plan task ID (`2.3`), or `quick`, `debugging`, or `correction` off the feature track |
| `date` | `YYYY-MM-DD` |

**Events:**
- `delivered` — the lesson was included in a prompt for this task.
- `applied` — the task's report says the lesson shaped the work.
- `not-relevant` — the lesson was delivered, and the report says it did not apply.
- `recurrence` — the checker, the maintainer reviewer, or the user caught a mistake this lesson already describes.

On the feature track the orchestrator writes all four. On quick, bugfix and debugging work only `recurrence` is written — no delivery bookkeeping there.

## Derived Counts

Counts are never stored. Compute them by reading **every** file in `.darwin/learnings/usage/` and filtering on the lesson's `id`:

- **`uses`** = the number of `applied` events.
- **`recurrences`** = the number of `recurrence` events.
- **`irrelevantStreak`** = the number of trailing `not-relevant` events since the last `applied` event (all of them, if it was never applied). Order the merged events by `date`, keeping file line order within a file; on a date tie between files, place `applied` after `not-relevant`, so a tie never pushes a lesson toward retirement. `delivered` and `recurrence` events do not reset the streak.

Thresholds come from `.darwin/config.json` (see the `execute` skill's Darwin Config section): promote at `uses + recurrences ≥ learnings.promoteAt` (default `3`); retire at `irrelevantStreak ≥ learnings.retireAfter` (default `10`).

## Selecting Lessons for a Set of Files

Given the files a task (or a research question) touches:

1. **Candidates** — lessons with `status: active` (`grep -l '^status: active' .darwin/learnings/*.md`).
2. **Scope match** — a lesson matches when any of its `scope` entries matches any of the files:
   - an entry ending in `/` is a directory prefix (`src/scans/` matches `src/scans/api/client.ts`);
   - an entry containing `*` is a glob, where `**` crosses directories (`src/**/*.ts`);
   - any other entry is an exact path.
3. **Rank** — most `uses + recurrences` first; on a tie, the higher `id` number (newer) first.
4. **Cap** — take at most **5**.

Deliver each selected lesson as its `id`, `summary`, and the `## Learning` section. The full file is there for anyone who needs the evidence.
