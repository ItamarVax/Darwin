---
name: finishing-development-branch
description: Verify per-task commits and the drift check, archive the change, and present structured options for integration and cleanup. Use when all implementation tasks are done and the evaluation has passed, or when the user wants to finish a feature branch.
---

# Finishing a Development Branch

Guide completion of development work after all tasks are implemented and the end-of-feature evaluation has passed.

**Core principle**: verify commits → present options → execute choice → clean up.

---

## Step 1 — Verify Readiness

Before proceeding, confirm all conditions:

1. **All tasks COMPLETE**: Open `.darwin/darwin-progress.md` and confirm every task in the task table (fix tasks `F<n>` included) shows `COMPLETE` status. Any other status (`PENDING`, `IN_PROGRESS`, `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, `BLOCKED` — see the `plan` skill's Status Vocabulary in `references/progress-file.md`) means execution is unfinished; a `DONE` or `DONE_WITH_CONCERNS` task must pass the wave gate and be committed first.
2. **Evaluation passed**: Confirm the Execution Log has a `### Evaluation — ✅ Approved` entry (written by `reviewing-implementation` after the checker and maintainer review). For a Darwin 4 plan still carrying `### Final Review — ✅ Review approved`, accept that heading instead.
3. **Behavior deltas applied** (standard and reduced modes — read the Overview's `Mode`): a `docs(behaviors): apply ... deltas` commit exists on the branch (`git log --oneline <base>..HEAD`). Legacy mode has no proposal and skips this.
4. **Drift check passes**: run `behavior-check.sh` from the worktree root (see "Running scripts" below). Exit `0` passes (show any warnings). On exit `1`, show its output verbatim — each ERROR names the capability and the fix (update its behavior file, or add a `Behavior-Change: none (<capability>) — <reason>` trailer on a new commit). On exit `2`, show the error.

**If any condition fails** — STOP. Do not proceed. Report which condition failed and what needs to happen first.

---

## Step 2 — Verify Commits

Per-task commits were made by the orchestrator during execution (after each task passed its wave gate). Verify they are all in place.

### Check commit history

```bash
git log --oneline -<N>
```

Where `<N>` is the number of tasks in the plan. Verify:
- Each task has a corresponding commit
- Commits follow conventional format: `{type}({scope}): Task {N} — {title}`
- No uncommitted changes remain for plan files: `git status --porcelain`

### If commits are missing

If any task's changes are uncommitted (e.g., due to interrupted execution):
1. Check `.darwin/darwin-progress.md` for which tasks are COMPLETE
2. Stage and commit the missing task's files using the execution log's "Files Modified" list
3. Use the same commit format: `{type}({scope}): Task {N} — {title}`

### If there are no commits at all

Fall back to the legacy single-commit approach:
- Collect files from all execution log entries
- Stage only those files: `git add <file1> <file2> ...`
- Create a single commit with the plan title

---

## Step 3 — Archive the Change

Before presenting integration options, archive the plan and the change proposal
to `.darwin/archive/<slug>/` so the user has a durable record of the completed
work. (Darwin 4 archives under `.darwin/plans/` are left untouched.)

### Running scripts

Darwin's scripts ship with the plugin, not with the user's project. Run them with
the worktree root as the working directory (they operate on relative `.darwin/` paths).
They live in `scripts/` in the Darwin plugin root — two directories above this skill's own directory (`<this-skill-dir>/../../scripts/`):

```bash
# Claude Code:
"${CLAUDE_PLUGIN_ROOT}/scripts/archive-change.sh"
"${CLAUDE_PLUGIN_ROOT}/scripts/behavior-check.sh"

# Cursor: resolve them from this skill's directory, e.g. for a local install
~/.cursor/plugins/local/darwin/scripts/archive-change.sh
~/.cursor/plugins/local/darwin/scripts/behavior-check.sh
```

(When developing Darwin itself, the plugin root and the project root coincide,
so `scripts/archive-change.sh` works too.)

`archive-change.sh`:
- Derives a slug from the git branch name (stripping conventional prefixes like `feat/`, `fix/`).
- Falls back to the first H1 of `.darwin/darwin-progress.md` if the branch is `main`, `master`, empty, or `HEAD`.
- Moves `.darwin/darwin-progress.md` → `.darwin/archive/<slug>/plan.md` and, when present, `.darwin/proposal.md` → `.darwin/archive/<slug>/proposal.md`.
- Fails loudly (non-zero exit) if `.darwin/archive/<slug>/` already exists.

After the script succeeds, commit the move:

```bash
git add -A .darwin/darwin-progress.md .darwin/proposal.md .darwin/archive/
git commit -m "chore(darwin): archive change to .darwin/archive/<slug>/"
```

Substitute `<slug>` with the actual directory created by the script.

If the script fails (collision, missing file, undecidable slug):
- Report the script's stderr verbatim to the user.
- **Do not proceed** to Step 4. The user must resolve the conflict manually
  (rename the existing archive, rename the branch, or skip archival).

---

## Step 4 — Present Options

Present exactly these 4 options. Do not ask open-ended questions.

```
Implementation complete and committed. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a pull/merge request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work
```

Replace `<base-branch>` with the `Base` field from the plan Overview (older plans without it: ask the user).

Wait for the user to choose before executing anything.

---

## Step 5 — Execute Choice

### Option 1: Merge locally

Execution runs inside the feature worktree, but the base branch is checked out at the
**main checkout** — `git checkout <base-branch>` from here would fail ("already checked
out"). Relocate to the main checkout first (this also frees the worktree for removal):

```bash
main_root="$(git worktree list --porcelain | sed -n 's/^worktree //p' | head -1)"
cd "$main_root"
git pull origin <base-branch>
git merge <feature-branch>
```

Verify the merge succeeded (check exit code, run `git log --oneline -3`).

Then clean up — remove the worktree **before** deleting the branch (a branch checked
out in a worktree cannot be deleted), and clear the breadcrumb:
```bash
git worktree remove <worktree-path>
git worktree prune
git branch -d <feature-branch>
rm -f .darwin/active-worktree
```

Report: "Merged `<feature-branch>` into `<base-branch>`. Branch deleted. Worktree removed."

### Option 2: Push and create pull/merge request

```bash
git push -u origin <feature-branch>
```

Report the push URL and suggest creating the request in the host's UI, or use the host CLI if available. Pick by the `origin` URL (`github.com` → `gh`, a GitLab host → `glab`):

```bash
gh pr create --title "<title>" --body "<description>"
# GitLab:
glab mr create --title "<title>" --description "<description>"
```

- **Title**: `KEY-123: <plan Overview title>` when the plan's Overview has a `Ticket`, otherwise the plan Overview title.
- **Description** — use this template (sections without content are omitted):

  ```markdown
  <ticket link, when present>

  ## Summary
  <the proposal's Why and Approach, 2–4 lines — from `.darwin/archive/<slug>/proposal.md`, where Step 3 moved it>

  ## Behavior changes
  <the proposal's ADDED / MODIFIED / REMOVED / NEW CAPABILITY lines>

  ## Evidence
  <the checker's behavior table from `### Evaluation — ✅ Approved` in `.darwin/archive/<slug>/plan.md`: ID | PASS/FAIL | evidence>
  - Suite: <command> — pass (baseline failures excluded: <list or none>)
  - Drift check: pass
  - Surviving mutants: <list or none>

  ## Tasks
  <each task's commit subject>
  ```

  Reviewers see what the product now does differently next to the diff — the behavior-file changes are in the MR too.

Pushing happens only here, because the user chose this option; no other step of this skill pushes.

**Keep the worktree** — the user may need it for merge request feedback and follow-up commits.

Report: "Pushed `<feature-branch>` to origin. Create a pull/merge request from the host's UI or use the command above. Worktree preserved for MR feedback."

### Option 3: Keep as-is

No cleanup. No push. No merge.

Report: "Keeping branch `<feature-branch>`. Worktree preserved at `<worktree-path>`."

### Option 4: Discard

**Requires typed confirmation.** Ask:

```
Type "discard" to confirm you want to permanently delete this branch and all its changes.
```

Only proceed after receiving the exact word "discard".

Relocate to the main checkout first (the base branch is checked out there, and the
worktree cannot be removed while your cwd is inside it). Remove the worktree **before**
deleting the branch, and clear the breadcrumb:

```bash
main_root="$(git worktree list --porcelain | sed -n 's/^worktree //p' | head -1)"
cd "$main_root"
git worktree remove --force <worktree-path>
git worktree prune
git branch -D <feature-branch>
rm -f .darwin/active-worktree
```

Report: "Branch `<feature-branch>` deleted. Worktree removed. All changes discarded."

---

## Worktree Cleanup Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|---|---|---|---|---|
| 1. Merge locally | Yes | No | Remove | `git branch -d` |
| 2. Push + MR | No | Yes | Keep (for MR feedback) | No |
| 3. Keep as-is | No | No | Keep | No |
| 4. Discard | No | No | Remove (force) | `git branch -D` |

---

## Safety

- **Never** proceed past Step 1 without the evaluation passing and the drift check clean
- **Never** delete a branch or worktree without explicit user choice
- **Never** force-push without the user explicitly requesting it
- **Never** use `git add .` or `git add -A` — only stage files from execution logs
- **Never** execute Option 4 (discard) without typed "discard" confirmation
- If `git merge` has conflicts, report them and let the user decide how to resolve

---

## Common Mistakes

| Mistake | Why it's wrong | Do this instead |
|---|---|---|
| Skipping verification | May commit broken or incomplete work | Always run Step 1 first |
| Asking "what do you want to do?" | Open-ended questions slow the user down | Present the 4 structured options |
| Auto-cleaning worktrees | User may need the worktree for follow-up | Only clean per the reference table |
| Using `git add .` | Stages unrelated files | Stage only files from execution logs |
| Skipping commit verification | May leave task changes uncommitted | Always run Step 2 to verify all per-task commits exist |
| Bypassing a failing drift check | Behavior files stop describing the product | Fix the behavior file or add the trailer, then re-run the check |

---

## Integration

Called by the `execute` skill after the evaluation passes (`### Evaluation — ✅ Approved`). Uses `scripts/archive-change.sh` and `scripts/behavior-check.sh`. Pairs with the `using-git-worktrees` skill for worktree lifecycle management.
