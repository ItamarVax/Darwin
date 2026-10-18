#!/usr/bin/env bash
# cli-support-disable.sh — Remove symlinks under ~/.cursor/skills and
# ~/.cursor/agents that point into this plugin. Hand-authored skills and
# agents (and symlinks pointing elsewhere) are left untouched.
#
# Idempotent: re-running is safe.
#
# Usage: bash scripts/cli-support-disable.sh

set -euo pipefail
shopt -s nullglob

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DST="$HOME/.cursor/skills"
AGENTS_DST="$HOME/.cursor/agents"
SKILLS_PREFIX="$PLUGIN_DIR/skills"
AGENTS_PREFIX="$PLUGIN_DIR/agents"

removed=0
kept=0

unlink_if_ours() {
  local path="$1" prefix="$2"
  if [ ! -L "$path" ]; then
    kept=$((kept + 1))
    return 0
  fi
  local target
  target="$(readlink "$path")"
  case "$target" in
    "$prefix"/*|"$prefix")
      unlink "$path"
      removed=$((removed + 1))
      ;;
    *)
      kept=$((kept + 1))
      ;;
  esac
}

if [ -d "$SKILLS_DST" ]; then
  for entry in "$SKILLS_DST"/*; do
    unlink_if_ours "$entry" "$SKILLS_PREFIX"
  done
fi

if [ -d "$AGENTS_DST" ]; then
  for entry in "$AGENTS_DST"/*; do
    unlink_if_ours "$entry" "$AGENTS_PREFIX"
  done
fi

echo "Done. removed=$removed kept=$kept"
