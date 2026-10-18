#!/usr/bin/env bash
# cli-link-framework.sh — Symlink the Darwin framework rule into the
# current project's .cursor/rules/ directory and add it to .gitignore.
#
# Run this from the root of the project where you want Darwin available
# to `cursor-agent` (the Cursor CLI). Idempotent.
#
# Usage (from project root):
#   ~/.cursor/plugins/local/darwin/scripts/cli-link-framework.sh

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$PLUGIN_DIR/rules/framework.mdc"
DST=".cursor/rules/framework.mdc"
GITIGNORE_ENTRY=".cursor/rules/framework.mdc"
GITIGNORE_COMMENT="# Darwin framework rule (symlinked from plugin)"

if [ ! -f "$SRC" ]; then
  echo "cli-link-framework: source missing: $SRC" >&2
  exit 2
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "cli-link-framework: not a git repository (run from project root)." >&2
  exit 3
fi

mkdir -p ".cursor/rules"

if [ -L "$DST" ]; then
  if [ "$(readlink "$DST")" = "$SRC" ]; then
    echo "framework.mdc symlink already correct — no change."
  else
    ln -sfn "$SRC" "$DST"
    echo "framework.mdc symlink updated: $DST -> $SRC"
  fi
elif [ -e "$DST" ]; then
  echo "cli-link-framework: $DST exists and is not a symlink — refusing to overwrite." >&2
  exit 4
else
  ln -s "$SRC" "$DST"
  echo "framework.mdc symlinked: $DST -> $SRC"
fi

if [ -f .gitignore ] && grep -Fxq "$GITIGNORE_ENTRY" .gitignore; then
  echo ".gitignore already contains $GITIGNORE_ENTRY."
else
  if [ -f .gitignore ] && [ -n "$(tail -c1 .gitignore 2>/dev/null)" ]; then
    printf '\n' >> .gitignore
  fi
  printf '%s\n%s\n' "$GITIGNORE_COMMENT" "$GITIGNORE_ENTRY" >> .gitignore
  echo "Added $GITIGNORE_ENTRY to .gitignore."
fi
