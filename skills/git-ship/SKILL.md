---
name: git-ship
disable-model-invocation: true
description: >
  Fast-track commit, push, and PR workflow.
---

# Git Ship

Automates the complete Git workflow: branch → commit → push → PR in a single command.

**Pushing is this skill's explicit purpose.** It pushes only because the user invoked `/git-ship` and chose a push strategy. No other Darwin skill or step pushes on its behalf, and git-ship never pushes beyond what the user selected.

## When This Skill Fires

- User says `/git-ship` or `/ship`

## When to Use

- ✅ Simple, single-purpose changes (docs, config, small features)
- ✅ Changes are complete and tested
- ✅ Quick fixes or updates

## When NOT to Use

- ❌ Complex features needing multiple commits
- ❌ Changes requiring team discussion
- ❌ Breaking changes needing careful review
- ❌ Untested changes

## Interactive Prompts

Respond with shorthand: `1.a 2.b 3.a` or `a b a`

1. **Branch strategy?**
   - a) Use current branch
   - b) Create new branch (specify name)
   - c) Create branch from commit message

2. **Commit message?**
   - a) Auto-generate from changes
   - b) Custom message (specify)

3. **Push strategy?**
   - a) Push only (no PR)
   - b) Push and create PR
   - c) Push, create PR, and request review

## Worktree Detection

Before shipping, detect if running inside a git worktree:

```bash
git_dir=$(git rev-parse --git-dir)
git_common_dir=$(git rev-parse --git-common-dir)
```

- **Same paths** → main worktree (standard repo)
- **Different paths** → inside a linked worktree

When in a worktree:
1. Report the worktree path and current branch
2. Warn if HEAD is detached
3. Verify the worktree is clean enough to proceed

## Execution Flow

1. **Detect** - Git state, changes, conflicts, worktree status
2. **Quality Check** - Invoke the `fix-all` skill (changed files only) before committing; it reads `commands.lint` / `commands.typecheck` from `.darwin/config.json`
3. **Branch** - Create/switch to appropriate branch
4. **Stage** - Add changed files
5. **Behavior Check** - Run the drift check on the staged change (see below); stop on exit `1`
6. **Commit** - Single commit with conventional format: `git commit -F <msg-file>`
7. **Push** - Push to remote with `-u` flag (the user's chosen push strategy)
8. **PR** - Create PR with auto-generated description (if selected)

## Behavior Check

After fix-all and staging, before committing:

1. Write the commit message to a temp file (e.g. `msg=$(mktemp)`).
2. Run `behavior-check.sh --staged` from the project (or worktree) root with `DARWIN_COMMIT_MSG_FILE` pointing at it. Resolve the script per the `execute` skill's "Running scripts" section:

   ```bash
   # Claude Code:
   DARWIN_COMMIT_MSG_FILE="$msg" "${CLAUDE_PLUGIN_ROOT}/scripts/behavior-check.sh" --staged

   # Cursor: the plugin root is two directories above this skill's directory, e.g.:
   DARWIN_COMMIT_MSG_FILE="$msg" ~/.cursor/plugins/local/darwin/scripts/behavior-check.sh --staged
   ```

3. Act on the exit code:
   - **`0`** → pass (show any warnings). Commit with `git commit -F "$msg"` — run it only after a `0` (chain with `&&`, never `;`).
   - **`1`** → show the script output and **stop**. Do not commit or push. Tell the user to either update the affected capability's behavior file under `.darwin/behaviors/`, or — if behavior is truly unchanged — add the trailer `Behavior-Change: none (<cap>) — <reason>` to the commit message (format: the `behaviors` skill's `references/formats.md` §3), then re-run `/git-ship`.
   - **`2`** → usage or environment error; show the output and stop.

The check is a no-op when `behaviors.enabled` is `false` in `.darwin/config.json` or `.darwin/behaviors/` does not exist.

## Commit Format

```
{type}: {description}
```

Types: feat, fix, docs, style, refactor, test, chore, ci, perf

## Pre-Ship Checklist

- [ ] Quality checks pass (see `development-commands.mdc`)
- [ ] Application/tests work as expected
- [ ] No debug code remains
- [ ] Code follows project standards (see `code-quality-standards.mdc`)

## Safety Features

- ✅ Run quality checks before commit
- ✅ Run the behavior drift check (`behavior-check.sh --staged`) before commit
- ✅ Push only as part of the user-invoked ship, per the chosen push strategy
- ✅ Validate commit message format
- ✅ Check for uncommitted changes
- ✅ Verify no sensitive files (credentials, .env)
- ✅ Handle merge conflicts gracefully

## Integration

- **Invokes**: `fix-all` skill (quality check before commit)
- **Runs**: `scripts/behavior-check.sh --staged` (drift check before commit; formats defined by the `behaviors` skill)
- **Configured by**: `.darwin/config.json` (see the `execute` skill's Darwin Config section)
- **Related**: `using-git-worktrees` skill, `finishing-development-branch` skill
