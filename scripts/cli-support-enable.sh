#!/usr/bin/env bash
# cli-support-enable.sh — Symlink Darwin skills and agents into ~/.cursor/
# so they are discoverable by `cursor-agent` (the Cursor CLI).
#
# Idempotent: re-running is safe. Only creates/updates symlinks; never
# overwrites real files or symlinks pointing elsewhere.
#
# Usage: bash scripts/cli-support-enable.sh

set -euo pipefail
shopt -s nullglob

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_SRC="$PLUGIN_DIR/skills"
AGENTS_SRC="$PLUGIN_DIR/agents"
SKILLS_DST="$HOME/.cursor/skills"
AGENTS_DST="$HOME/.cursor/agents"

mkdir -p "$SKILLS_DST" "$AGENTS_DST"

linked=0
ok=0
conflict=0

link_one() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then
      ok=$((ok + 1))
      return 0
    fi
  elif [ -e "$dst" ]; then
    echo "  conflict: $dst exists and is not a symlink — skipping" >&2
    conflict=$((conflict + 1))
    return 0
  fi
  ln -sfn "$src" "$dst"
  linked=$((linked + 1))
}

echo "Plugin root: $PLUGIN_DIR"
echo "Linking skills -> $SKILLS_DST"
for d in "$SKILLS_SRC"/*/; do
  name="$(basename "${d%/}")"
  link_one "${d%/}" "$SKILLS_DST/$name"
done

echo "Linking agents -> $AGENTS_DST"
for f in "$AGENTS_SRC"/*.md; do
  name="$(basename "$f")"
  link_one "$f" "$AGENTS_DST/$name"
done

echo "Done. linked=$linked already-correct=$ok conflicts=$conflict"
[ "$conflict" -eq 0 ]
