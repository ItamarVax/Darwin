---
name: behaviors
description: >
  Living behavior files — short, per-capability descriptions of what the
  product does (WHEN/THEN requirements with permanent IDs, linked to the tests
  that prove them), kept current by every change and checked by a strict drift
  check. Use when the user says /behaviors, asks to capture or confirm a
  behavior file, asks what a capability must do, or when another Darwin skill
  needs the behavior-file, change-proposal, or Behavior-Change trailer format.
---

# Behaviors

Behavior files record **what the product does**, one file per capability, in
`.darwin/behaviors/`. Every Darwin change updates them, so they stay true to the
code — the drift check (`scripts/behavior-check.sh`) blocks changes that alter
covered code without updating its behavior file or declaring that behavior did
not change.

**Core principle**: what, never how. A behavior file states requirements a user
or caller could observe, each tied to the tests that prove it. Implementation
detail belongs in the code.

The formats — behavior file, change proposal, and the `Behavior-Change`
trailer — are defined once, in [references/formats.md](references/formats.md).
Read it before writing any of them.

## When This Skill Fires

- User says `/behaviors`, `/behaviors capture <capability>`, or `/behaviors confirm <capability>`
- User asks what a capability must do, or asks to document or confirm behavior
- Another skill needs a format: `onboarding` (initial capture), `research` (lookup), `innovate` and `plan` (change proposal), `execute` (applying deltas), `quick` and `systematic-debugging` (small edits, the trailer), `finishing-development-branch` (drift check)

## Constraints

- **Allowed**: Reading code and tests, writing and editing `.darwin/behaviors/*.md`, running `scripts/behavior-check.sh`
- **Forbidden**: Changing application code or tests, renumbering or reusing requirement IDs, marking a requirement `intended` without the user's confirmation, describing implementation detail in a behavior file
- During a feature's execution, the execute orchestrator is the only writer of behavior files

## Where Behavior Files Come From

Behavior files grow where work happens. There is no whole-repository capture.

1. **Onboarding** — the user picks a few core capabilities; each is captured with every requirement `Status: observed`.
2. **A feature touching uncovered code** — its change proposal declares a `NEW CAPABILITY` (or extends an existing capability's `paths`), and the deltas create the file when execution finishes.
3. **On request** — `/behaviors capture <capability>`.

## Process

### `/behaviors capture <capability>`

1. **Scope**: confirm the capability name and propose its `paths` from the code layout. If a behavior file already covers those paths, say so and stop.
2. **Read**: the code under `paths` and the tests that exercise it. When a `darwin-researcher` dispatch is cheaper than reading in the main session (more than a handful of files), dispatch it with the capability as the topic.
3. **Draft**: write `.darwin/behaviors/<capability>.md` per the format. Every requirement is `Status: observed`. Point `Tests:` at existing tests that check the requirement, or write `none yet`. Stay under ~150 lines — capture the behaviors a user or caller relies on, not every branch in the code.
4. **Review**: show the user the draft. Offer `/behaviors confirm` for it right away.
5. **Check**: run `scripts/behavior-check.sh` (see "Running the drift check") and fix any integrity error it reports.

### `/behaviors confirm <capability>`

Walk the file's `observed` requirements one at a time:

- **Confirmed as intended** → set `Status: intended`. An intended requirement needs at least one test pointer; if it has `none yet`, say so and suggest adding a test in the next change that touches it (the file keeps `observed` until then).
- **Wrong** (the code has a bug) → leave it `observed`, and suggest `/systematic-debugging` for the bug.
- **No longer wanted** → note it for the next change proposal to remove; do not tombstone it outside a change.

### Answering "what does X do?"

Find the behavior files whose `paths` cover X and answer from their
requirements, naming the IDs. Say when a requirement is only `observed`. If no
file covers X, say so and offer `/behaviors capture`.

## Running the drift check

The script lives in the Darwin plugin, not in the project:

```bash
# Claude Code:
"${CLAUDE_PLUGIN_ROOT}/scripts/behavior-check.sh"

# Cursor: resolve it from this skill's directory — the plugin root is two
# directories above it, e.g. for a local install:
~/.cursor/plugins/local/darwin/scripts/behavior-check.sh
```

Run it from the project (or worktree) root. Exit `0` = pass (warnings may be
printed), `1` = violations, `2` = usage or environment error. Flags: `--base
<ref>`, `--staged` (also check staged files; pass a pending commit message via
the `DARWIN_COMMIT_MSG_FILE` environment variable), `--quiet`.

## Integration

- **Defines**: the behavior-file, change-proposal, and `Behavior-Change` trailer formats ([references/formats.md](references/formats.md))
- **Used by**: `onboarding`, `research`, `innovate`, `plan`, `execute`, `quick`, `systematic-debugging`, `finishing-development-branch`, `git-ship`, `darwin-checker`
- **Script**: `scripts/behavior-check.sh` (the drift check)
- **Configured by**: `behaviors.enabled` and `behaviors.strictUncovered` in `.darwin/config.json` (see the `execute` skill's Darwin Config section)
