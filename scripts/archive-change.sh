#!/usr/bin/env bash
# archive-change.sh — Archive the finished Darwin change to .darwin/archive/.
#
# Moves .darwin/darwin-progress.md → .darwin/archive/<slug>/plan.md and, when
# present, .darwin/proposal.md → .darwin/archive/<slug>/proposal.md. The slug
# derives from the current git branch (stripping the conventional <word>/
# prefix, e.g. feat/, fix/). If the branch is unhelpful (main, master, empty,
# HEAD), falls back to the first H1 of the progress file slugified.
#
# Invoked by the finishing-development-branch skill after the evaluation has
# passed and all per-task commits are in place. Fails loudly if the archive
# directory already exists, rather than silently overwriting prior history.
# Replaces archive-plan.sh (Darwin 4), whose single-file archives under
# .darwin/plans/ are left untouched.
#
# Does NOT touch the .darwin/active-worktree breadcrumb: archiving happens
# before the user picks an integration option, and only merge and discard
# end the worktree's life (finishing clears the breadcrumb for those).
#
# Usage (from project root or worktree root):
#   scripts/archive-change.sh

set -euo pipefail

PROGRESS_FILE=".darwin/darwin-progress.md"
PROPOSAL_FILE=".darwin/proposal.md"
ARCHIVE_ROOT=".darwin/archive"

if [ ! -f "$PROGRESS_FILE" ]; then
  echo "archive-change: no progress file at $PROGRESS_FILE — nothing to archive." >&2
  exit 1
fi

slugify() {
  # Lowercase; replace runs of non-alphanumerics with single hyphen; trim.
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

branch="$(git branch --show-current 2>/dev/null || true)"
branch_stripped="$(printf '%s' "$branch" | sed -E 's|^[a-zA-Z]+/||')"
slug=""

case "$branch_stripped" in
  ""|main|master|HEAD)
    title="$(grep -m1 '^# ' "$PROGRESS_FILE" 2>/dev/null | sed -E 's/^#[[:space:]]+//')"
    if [ -z "$title" ]; then
      echo "archive-change: cannot derive slug — branch is '$branch' and progress file has no H1." >&2
      exit 2
    fi
    slug="$(slugify "$title")"
    ;;
  *)
    slug="$(slugify "$branch_stripped")"
    ;;
esac

if [ -z "$slug" ]; then
  echo "archive-change: slug derivation produced empty string." >&2
  exit 3
fi

target="$ARCHIVE_ROOT/$slug"

if [ -e "$target" ]; then
  echo "archive-change: $target already exists — refusing to overwrite." >&2
  echo "Resolve manually: rename or remove the existing archive, or rename the branch." >&2
  exit 4
fi

mkdir -p "$target"
mv "$PROGRESS_FILE" "$target/plan.md"
echo "archive-change: archived $PROGRESS_FILE -> $target/plan.md"
if [ -f "$PROPOSAL_FILE" ]; then
  mv "$PROPOSAL_FILE" "$target/proposal.md"
  echo "archive-change: archived $PROPOSAL_FILE -> $target/proposal.md"
fi
