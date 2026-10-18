# Darwin Formats: Behavior Files, Change Proposals, and the Behavior-Change Trailer

This file is the single definition of these three formats. Every skill, agent,
and script that reads or writes them follows it — `scripts/behavior-check.sh`
parses them exactly as written here.

---

## 1. Behavior file

**Location**: `.darwin/behaviors/<capability>.md`, committed to the project.

A **capability** is a user-facing area of behavior ("export", "auth",
"scan-scheduling") — not a code folder. The file describes **what** the
product does, never **how** it is implemented: no class names, algorithms, or
internal structure. Those go stale fastest.

### Structure

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
Tests: none yet

### EXPORT-3: Excel output
Status: removed
Reason: Excel export dropped in favor of CSV (change: drop-excel-export)
```

### Rules

| Element | Rule |
|---------|------|
| Frontmatter `capability` | Lowercase, hyphenated; equals the file name without `.md` |
| Frontmatter `paths` | A YAML flow list of path prefixes (a trailing `/` means a directory) or globs (`*`, `**`). Drives research lookup, lesson delivery, and the drift check |
| `# Title` | One H1, the capability's display name |
| `Purpose:` | One line |
| Requirement heading | Exactly `### <CAP>-<n>: <title>` — `<CAP>` is the capability in uppercase with hyphens kept (`scan-scheduling` → `SCAN-SCHEDULING`), `<n>` a positive integer |
| `Status:` | `intended` (a human decided or confirmed it), `observed` (recorded from existing code — may encode a bug), or `removed` (a tombstone) |
| `WHEN` / `THEN` | One or more `WHEN …` lines, then one or more `THEN …` lines (`AND …` continues either). Required for `intended` and `observed` |
| `Tests:` | `intended`: one or more `path::test-name` pointers, comma-separated. `observed`: pointers, or exactly `none yet`. `removed`: no `Tests:` line |
| `Reason:` | Required for `removed`; one line |

**IDs are permanent.** An ID is never renumbered and never reused, even after
removal — that is what tombstones are for. A new requirement takes the next
integer after the highest ever used in that file, tombstones included.

**Observed vs intended.** A requirement captured from existing code is
`observed` until a human confirms it — during onboarding, via
`/behaviors confirm`, or when an approved change proposal adds or modifies it
*and* a test proves it. Never treat an `observed` requirement as a decided rule:
the code it was read from may be wrong. In reduced mode (no test suite), a
requirement an approved proposal adds or modifies is written as `observed` with
`Tests: none yet`, because `intended` always needs a test pointer; it becomes
`intended` once a later change adds the test.

**Size.** Aim for about 150 lines per file. Past that, split the capability.

### Test pointers

`Tests: tests/export/test_csv.py::test_empty_export` means: the file
`tests/export/test_csv.py` exists and contains the string `test_empty_export`.
Use the test runner's own identifier when it has one (pytest node names, a Go
`TestXxx` name, a Jest `it(...)` title). The drift check takes the part before
the first `::` as the path and the part after the **last** `::` as the name, so
a pytest class node `tests/x.py::TestCsv::test_header` checks for
`test_header`. It resolves the name with a plain substring match, so the name
must appear verbatim in the file. Pointers are comma-separated; a comma inside a
test title is fine, because a new pointer only starts where the next piece
contains `::`.

---

## 2. Change proposal

**Location**: `.darwin/proposal.md`. Written in the main checkout by `innovate`
(or by `plan` when innovate is skipped), moved into the feature worktree at plan
finalization, committed with the plan, and archived with it to
`.darwin/archive/<slug>/proposal.md` by `finishing-development-branch`.

The proposal is the main thing the user reviews and approves for a feature.
Keep it short — a reviewer should read it in two minutes.

### Structure

```markdown
# Change: Stream large exports
Why: exports over ~100k rows time out and exhaust memory.
Approach: Stream rows from the query cursor straight to the response writer;
keep the in-memory path for small exports. Rejected: background export job
(adds a queue and a polling UI for a problem streaming solves).
Out of scope: Excel output; export scheduling.
Test suite: present

## Behavior changes
ADDED EXPORT-7: WHEN an export exceeds 100k rows THEN rows stream and memory stays bounded | Verify: integration test
MODIFIED EXPORT-2: WHEN an export exceeds 50k rows THEN the response is streamed | Verify: unit test
REMOVED EXPORT-4: Excel output — replaced by CSV
NEW CAPABILITY report-sharing: paths [src/sharing/] — users share a scan report by link
```

### Rules

| Element | Rule |
|---------|------|
| `# Change:` | One line naming the change |
| `Why:` / `Approach:` / `Out of scope:` | Short paragraphs. `Approach` names the rejected alternatives in one line each |
| `Test suite:` | `present`, or `none (reduced mode)` when the project has no test command and the user declined test setup |
| `## Behavior changes` | One line per change, each starting with one of the four keywords below |
| `ADDED <ID>: WHEN … THEN … \| Verify: <how>` | A new requirement. `<ID>` is the next free number in that capability |
| `MODIFIED <ID>: WHEN … THEN … \| Verify: <how>` | The full new wording of an existing requirement |
| `REMOVED <ID>: <reason>` | Becomes a tombstone when deltas are applied |
| `NEW CAPABILITY <name>: paths [<p>, …] — <purpose>` | Creates `.darwin/behaviors/<name>.md`; its requirements are listed as `ADDED` lines |
| `Verify:` | `unit test`, `integration test`, or `exercise app` — how the change will be shown to work |

A proposal may also extend an existing capability's `paths` with a line
`PATHS <capability>: add [<p>, …]` when the change adds code under a new path
that belongs to an existing capability.

### Applying the deltas

At the end of execution the orchestrator — the only writer — applies the
proposal to `.darwin/behaviors/`:

- `ADDED` → append a `### <ID>: <title>` block with `Status: intended`, the WHEN/THEN lines, and the `Tests:` pointers of the tests that cover it (reduced mode: `Status: observed`, `Tests: none yet`)
- `MODIFIED` → replace the block's WHEN/THEN, set `Status: intended`, update `Tests:` (reduced mode: `Status: observed`, keep existing pointers or `none yet`)
- `REMOVED` → replace the block with a tombstone (`Status: removed` + `Reason:`)
- `NEW CAPABILITY` → create the file with frontmatter, title, and purpose
- `PATHS` → extend the capability's `paths`

---

## 3. The Behavior-Change trailer

A commit that changes code under a capability's `paths` without changing what
the product does — a refactor, a rename, a performance fix — declares it with a
git trailer in the commit message, exactly:

```
Behavior-Change: none (<capability>) — <reason>
```

Example:

```
refactor(export): split csv writer into its own module

Behavior-Change: none (export) — internal restructure, same output
```

One trailer per capability touched. The drift check accepts it in place of an
update to that capability's behavior file. Use it only when behavior is truly
unchanged — if a test had to change its expectations, behavior changed.
