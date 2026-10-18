---
name: quick
description: >
  Lightweight single-pass workflow for small, well-understood changes — the
  direct track (a one-line change, typo, or rename whose diff fits in one
  sentence) and the quick track (a change you can describe fully before
  starting, no design decisions, no architectural impact). Skips worktree
  creation, subagent dispatch, and the full RIPER chain: inline mini-plan,
  implement, self-review, verify, drift check, single commit. Use when the
  user says /quick, or asks for a one-line change, small fix, typo, config
  tweak, or doc change where full planning ceremony would cost more than the
  change itself.
---

# Quick

> Begin every reply with `[MODE: QUICK]`. See `using-darwin` for the full contract.

One pass from request to commit for changes too small to justify the full
Research → Innovate → Plan → Execute → Review chain.

**Core principle**: ceremony proportional to risk. Small change, small process —
but never zero process. Verification, the drift check, and (on the quick track)
the mini-plan and self-review are not optional.

## When This Skill Fires

- User says `/quick` or "quick fix", "just change X", "small tweak", "one-line change"
- The change is small, concrete, and fully understood up front

## Track Choice

At the start of any request, state the track in one line — e.g. "Treating this
as a quick change: 2 files, no design questions." The user can override it.

| Track | When | Process |
|---|---|---|
| **direct** | The diff fits in one sentence; the location is obvious | No mini-plan, no confirmation: do it, verify, drift check, commit |
| **quick** | Small, clear, fully describable before starting; no open design question | Mini-plan; confirmation only when you inferred the scope rather than the user stating it |
| **bugfix** | Something is broken, with expected behavior known or knowable | Hand to `systematic-debugging` |
| **feature** | New or changed behavior, multi-file and uncertain, unfamiliar code, or shared contracts | Recommend `/research` (understanding is the gap) or `/plan` |

This skill runs the direct and quick tracks only.

## When NOT to Use

Recommend the full chain (`/research` or `/plan`) instead when **any** of these hold:

- You cannot describe the full change before starting (file count is a
  heuristic: more than ~3 files usually means you can't)
- Any design decision is open (API shape, naming a new concept, data model)
- The change touches shared contracts other code depends on
- The change needs a new capability — it adds behavior to code no behavior file covers
- The user asks for a feature, not a fix or tweak

Something broken → `systematic-debugging` (bugfix track), not this skill.

`/git-ship` remains the right tool when the work is already done and only needs
to be committed/pushed.

## Constraints

- **Allowed**: Reading code, making the agreed changes directly in the main session, running verification commands and the drift check, editing the affected `.darwin/behaviors/` file, a single commit
- **Forbidden**: Worktree creation, subagent dispatch, scope growth beyond the approved checklist, `git add .` / `git add -A`, `git push` (suggest `/git-ship` instead)
- All Darwin safety hooks remain active (dangerous-command blocking, session state)

## Process

### Step 1 — Scope Check

State the track (see Track Choice). Verify the request fits the criteria
above. If it doesn't, say which criterion fails and recommend `/plan` (or
`/research` if understanding is the gap, or `systematic-debugging` for a bug).
Do not proceed with an oversized change "just this once".

Check `.darwin/behaviors/` (when it exists): find the behavior files whose
`paths` cover the files you will change, and read the requirements that apply.

### Step 2 — Mini-Plan (quick track only)

**Direct track**: skip this step — no mini-plan, no confirmation.

**Quick track**: present a short checklist. Wait for a go-ahead (one
confirmation, not a planning session) **only when you inferred the scope** —
the user didn't name the change and its location. When the user stated the
scope exactly, show the checklist and proceed.

```
Quick change plan:
- [ ] <file>: <change>
- [ ] <file>: <change>
Behaviors: <capability file to edit | Behavior-Change: none (<cap>) — <reason> | not covered>
Verify with: <command or check>
Commit as: <type>(<scope>): <description>
Refs: <KEY-123, when started from a ticket>

Proceed?
```

### Step 3 — Implement

Make exactly the changes in the checklist (or the one-sentence change, on the
direct track), directly in the main session. Read each file before editing it.

### Step 4 — Behaviors

Skip when `.darwin/behaviors/` does not exist or `behaviors.enabled` is `false`
in `.darwin/config.json`. Otherwise, for each capability whose `paths` cover a
changed file:

- **The change alters behavior the file describes** → edit that behavior file
  in the same commit, per the `behaviors` skill's format
  ([../behaviors/references/formats.md](../behaviors/references/formats.md)).
  Keep it a small edit: keep existing IDs, a new requirement takes the next
  free number, and a removed one becomes a tombstone. A new or changed
  requirement is `Status: intended` only with a test pointer that proves it;
  otherwise it is `Status: observed`.
- **Behavior is unchanged** → add the trailer to the commit message, one per
  capability:

  ```
  Behavior-Change: none (<capability>) — <reason>
  ```

Changed files no behavior file covers need nothing on this track (the drift
check warns) — unless the change adds behavior that deserves a capability;
then the scope guard applies.

### Step 5 — Self-Review (quick track; a glance on direct)

Run the executor's checklist on your own work:

- **Completeness**: Everything in the checklist done? Nothing missed?
- **Quality**: Names clear, style matches surrounding code?
- **Discipline**: Nothing built beyond the checklist (YAGNI)?
- **Standards**: Follows `code-quality-standards.mdc` when present?

### Step 6 — Verify

Run `commands.test` and `commands.lint` from `.darwin/config.json` (see the
`execute` skill's Darwin Config section; replace `{files}` with the changed
files), falling back to `development-commands.mdc` when the config has no
commands. If neither defines them, say so in one line ("No test/lint command
configured — verified by <manual check> only") and continue; this is a
warning, not a stop.

If verification fails, fix and re-verify; if it keeps failing, stop and report
rather than committing broken work.

### Step 7 — Drift Check and Commit

Stage **only** the changed files (plus the behavior file from Step 4). Write
the commit message — a single conventional commit, with a `Refs: KEY-123`
trailer when the request named a ticket (`/quick PROJ-123 …` — fetch it per the
`research` skill's Ticket Entry Point to confirm scope), and any
`Behavior-Change` trailers — to a temp file, run the drift check against the
staged changes with that message, then commit from the same file:

```bash
msg=$(mktemp)
# write the commit message to "$msg"
# Commit only if the drift check passes — never chain these with ";".
DARWIN_COMMIT_MSG_FILE="$msg" "<plugin-root>/scripts/behavior-check.sh" --staged && git commit -F "$msg"
```

Resolve `<plugin-root>` per the `behaviors` skill's "Running the drift check"
(Claude Code: `${CLAUDE_PLUGIN_ROOT}`). Run `behavior-check.sh --staged` from
the project root. Exit `0` → commit (warnings are fine; mention uncovered-code
warnings in one line). Exit `1` → fix what it reports (edit the behavior file,
add a trailer, fix a broken `Tests:` pointer) and re-run; if the right fix is
unclear, ask the user. Never commit past an error.

**Never push.** If the user wants push + PR, suggest `/git-ship`.

## Scope Guard

If at any point during implementation:

- the change stops being one you could have described fully up front (a 4th
  file is a strong hint), or
- a design decision surfaces, or
- the change turns out to couple into code you didn't anticipate, or
- the change reaches an uncovered area that needs a new capability (new
  behavior no behavior file describes)

**STOP.** Summarize what's done so far, leave the work uncommitted (offer to
stash), and recommend the feature track (`/plan`). Escalating is the success
path here — silently growing a "quick" change into an unplanned feature is the
failure mode this guard exists to prevent.

A direct change that turns out to need more than one sentence moves to the
quick track: present the mini-plan.

## Capturing Lessons

When something went wrong during this change — a test that kept failing, an escalation, a correction from the user, a wrong first guess at the cause — end with the `compound` skill's **Light Capture Mode**: one question ("worth remembering?"), or, when the mistake matches an existing lesson in `.darwin/learnings/`, a `recurrence` event for that lesson instead of a new one. Nothing went wrong → skip it.

## Integration

- **Alternative to**: the full `/research` → `/innovate` → `/plan` → `/execute` chain, for changes that don't need it
- **Escalates to**: `plan` skill (via the scope guard), `research` skill (when understanding is missing), `systematic-debugging` (bugfix track)
- **Related**: `git-ship` (push/PR after the commit), `fix-all` (project-wide quality pass), `behaviors` (formats, drift check)
- **References**: `.darwin/config.json` (`commands.*`, `behaviors.*` — defined in the `execute` skill), `code-quality-standards.mdc`, `development-commands.mdc`
