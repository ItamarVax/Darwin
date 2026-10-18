---
name: using-git-worktrees
description: Set up isolated git worktree workspace for feature work. Invoked by the plan skill at finalization to create the feature worktree (execute does NOT create worktrees — it enters the one recorded in the plan). Use when starting feature work or when the user mentions worktrees, branches, or isolation.
---

# Using Git Worktrees

Git worktrees create isolated workspaces sharing the same repository — separate
working directories, each on their own branch, all backed by a single `.git` store.

**Core principle**: systematic directory selection + safety verification = reliable isolation.

## When This Skill Fires

- `plan` invokes this skill at finalization to create the feature worktree (after the plan is approved, before `/execute`)
- User asks to start feature work on a branch
- User mentions worktrees, isolation, or parallel development

## Directory Selection Process

Select the worktree root directory using this priority order:

| Priority | Condition | Action |
|----------|-----------|--------|
| 1 | `.worktrees/` exists in project root | Use `.worktrees/` |
| 2 | `worktrees/` exists in project root | Use `worktrees/` (`.worktrees/` wins if both exist) |
| 3 | Neither exists | Ask user to choose (see below) |

**When asking the user**, present two options:

- **a) `.worktrees/`** — project-local, hidden directory (recommended for single-machine use)
- **b) `~/.cursor/worktrees/<project>/`** — global directory shared across workspaces

```bash
project_name=$(basename "$(git rev-parse --show-toplevel)")
```

## Safety Verification

**For project-local directories** (`.worktrees/` or `worktrees/`):

Before creating any worktree, verify the directory is git-ignored:

```bash
git check-ignore -q .worktrees 2>/dev/null
```

- **Exit code 0**: Directory is ignored — safe to proceed.
- **Non-zero exit code**: Directory is NOT ignored — add it to the clone-local exclude file before proceeding. This keeps the main checkout's tracked files (including `.gitignore`) untouched; the exclude file is shared by every worktree of the clone.

```bash
echo ".worktrees/" >> "$(git rev-parse --path-format=absolute --git-common-dir)/info/exclude"
```

After adding, re-verify with `git check-ignore -q` to confirm.

**For global directories** (`~/.cursor/worktrees/`): no ignore check needed — the
directory is outside the repository.

## Create Worktree

### Steps

1. **Detect project name**:
   ```bash
   project_name=$(basename "$(git rev-parse --show-toplevel)")
   ```

2. **Determine worktree path** using the directory selection process above:
   ```bash
   # Project-local example:
   worktree_path=".worktrees/<branch-name>"

   # Global example:
   worktree_path="$HOME/.cursor/worktrees/$project_name/<branch-name>"
   ```

3. **Create worktree with new branch**:
   ```bash
   git worktree add <worktree_path> -b <branch-name>
   ```

   If the branch already exists, omit `-b`:
   ```bash
   git worktree add <worktree_path> <branch-name>
   ```

4. **Auto-detect and run project setup**:

   | File detected | Setup command |
   |---------------|---------------|
   | `requirements.txt` | `pip install -r requirements.txt` |
   | `pyproject.toml` | `pip install -e .` or `pip install -e ".[dev]"` |
   | `package.json` | `npm install` |
   | `Cargo.toml` | `cargo build` |

   Run the appropriate command inside the new worktree directory.

   The baseline test run is done by the `plan` skill after the progress file moves into the worktree (not here).

5. **Report**:
   > Worktree ready at `<worktree_path>` on branch `<branch-name>`. Ready to implement.

### `.cursor/` Symlink Guidance

New worktrees do not inherit untracked `.cursor/` content from the main worktree.
When the worktree is created by `/plan` finalization, the plan skill creates this
symlink automatically. For manually created worktrees, share rules, commands, and
skills with a symlink:

```bash
ln -s /path/to/main/.cursor /path/to/worktree/.cursor
```

Example:
```bash
ln -s /Users/me/project/.cursor /Users/me/project/.worktrees/feature-x/.cursor
```

This ensures the worktree uses the same framework configuration as the main workspace.

## List Worktrees

Display all worktrees with status annotations:

```bash
git worktree list
```

For each worktree, check and annotate:

```bash
# Check for uncommitted changes in a worktree
git -C <worktree_path> status --porcelain
```

- **Empty output** → annotate as `(clean)`
- **Non-empty output** → annotate as `(dirty — N uncommitted changes)`

**Example output**:

```
/Users/me/project              abc1234 [main]           (clean)
/Users/me/project/.worktrees/feat  def5678 [feat/new-api]   (dirty — 3 uncommitted changes)
```

## Remove Worktree

### Steps

1. **Check for uncommitted changes**:
   ```bash
   changes=$(git -C <worktree_path> status --porcelain)
   ```

2. **If dirty, warn the user**:
   > ⚠ Worktree at `<path>` has uncommitted changes:
   > ```
   > <list of changed files>
   > ```
   > Proceed with removal? This will discard these changes.

   Wait for explicit confirmation before continuing.

3. **Remove the worktree**:
   ```bash
   git worktree remove <worktree_path>
   ```

   If removal fails due to untracked files:
   ```bash
   git worktree remove --force <worktree_path>
   ```

4. **Prune stale references**:
   ```bash
   git worktree prune
   ```

5. **Optionally delete the branch** (ask user):
   ```bash
   git branch -d <branch-name>
   ```

## Quick Reference

| Situation | Action |
|-----------|--------|
| Finalizing `/plan` | Create worktree with the plan-derived branch name (`feat/<slug-of-title>`) |
| Starting `/execute` | Enter the worktree recorded in the progress file (already created at plan finalization) |
| User asks to work on a feature | Create worktree with feature branch name |
| User asks "what worktrees exist?" | Run list operation with dirty/clean status |
| User wants to clean up a worktree | Run remove operation with safety checks |
| Worktree missing `.cursor/` rules | Symlink `.cursor/` from main worktree |
| User switches between worktrees | `cd <worktree_path>` — each is independent |
| Branch already exists | `git worktree add <path> <branch>` (no `-b`) |
| Worktree path already in use | Report conflict and ask user for resolution |

## Common Mistakes

| Mistake | Why it's a problem | Prevention |
|---------|-------------------|------------|
| Skipping ignore verification | Worktree directory gets committed to repo | Always run `git check-ignore` before creating project-local worktrees |
| Assuming directory location | Creates worktrees in unexpected places | Follow the directory selection priority order every time |
| Proceeding with failing baseline | Broken dependencies in new worktree | Always run project setup and verify it succeeds; the baseline test run itself happens in the `plan` skill after the progress file moves into the worktree (see step 4) |
| Forgetting `.cursor/` symlink | Worktree lacks framework rules and commands | Create the symlink as part of worktree setup (plan finalization does this automatically) |
| Force-removing dirty worktree | Loses uncommitted work silently | Always check and warn about uncommitted changes first |

## Integration

- **Called by**: `plan` at finalization (after approval) to create the isolated workspace, before `/execute`
- **Pairs with**: `finishing-development-branch` skill for branch completion and worktree cleanup
- **Related commands**: `/git-ship`, `/git-cleanup`

