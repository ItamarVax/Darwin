---
name: git-cleanup
disable-model-invocation: true
description: >
  Clean up merged branches and stale worktrees.
---

# Git Cleanup

Automated cleanup of Git branches with safety checks and pattern-based filtering.

## When This Skill Fires

- User says `/git-cleanup` or `/cleanup`

## When to Use

- After merging feature branches
- Periodic repository maintenance
- Before starting new development cycle
- Cleaning up stale branches

## Interactive Prompts

Respond with shorthand: `1.a 2.b` or `a b`

1. **Cleanup scope?**
   - a) Local branches only
   - b) Remote branches only
   - c) Both local and remote
   - d) Worktrees (clean up stale worktrees)
   - e) All (branches + worktrees)

2. **Which branches to keep?**
   - a) Only main/master
   - b) Main + current branch
   - c) Main + specific pattern (specify)
   - d) Custom pattern (specify)

3. **Safety confirmation?**
   - a) Show preview first, then confirm
   - b) Execute immediately (use with caution)

## Execution Flow

1. **Detect** - Current branch, uncommitted changes, remote status, worktree state
2. **Preview** - List branches/worktrees to be deleted (if requested)
3. **Switch** - Move to safe branch (main) if needed
4. **Update** - Pull latest main
5. **Delete** - Remove branches except protected patterns
6. **Prune** - Clean up stale remote references and worktree references
7. **Worktree Cleanup** - Remove stale worktrees (if scope d or e selected)
8. **Report** - Summary with counts

## Worktree Cleanup

When scope **d) Worktrees** or **e) All** is selected:

1. `git worktree list` to show all linked worktrees
2. Check each worktree for uncommitted changes
3. Remove clean worktrees: `git worktree remove <path>`
4. Prune stale references: `git worktree prune`
5. **Clear stale Darwin breadcrumb**: if `.darwin/active-worktree` at the main checkout root points at a worktree that was just removed (or no longer exists), delete it — otherwise the session-start hook keeps suggesting `/resume` forever:
   ```bash
   bc=".darwin/active-worktree"
   [ -f "$bc" ] && [ ! -d "$(cat "$bc")" ] && rm -f "$bc"
   ```

The main worktree is never removed.

## Safety Features

- ✅ Preview mode before execution
- ✅ Auto-switch from branch to be deleted
- ✅ Update main before cleanup
- ✅ Skip branches with uncommitted changes
- ✅ Continue on individual failures
- ✅ Never delete main/master

## Integration

- **Related**: `git-ship` skill, `using-git-worktrees` skill, `finishing-development-branch` skill
