#!/usr/bin/env bash
# cli-unlink-framework.sh — Remove the framework.mdc symlink from this
# project if (and only if) it points into this plugin. Leaves .gitignore
# untouched.
#
# Run this from the root of the target project. Idempotent.
#
# Usage (from project root):
#   ~/.cursor/plugins/local/darwin/scripts/cli-unlink-framework.sh

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$PLUGIN_DIR/rules/framework.mdc"
DST=".cursor/rules/framework.mdc"

if [ ! -L "$DST" ]; then
  echo "No framework.mdc symlink at $DST — nothing to do."
  exit 0
fi

target="$(readlink "$DST")"
if [ "$target" = "$SRC" ]; then
  unlink "$DST"
  echo "Removed framework.mdc symlink (was -> $SRC)."
else
  echo "framework.mdc at $DST points to $target (not this plugin) — leaving alone."
fi
