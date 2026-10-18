#!/usr/bin/env bash
# Shared utilities for Darwin hooks.
# Source this file: source "$(dirname "$0")/lib.sh"

set -euo pipefail

read_stdin() {
  HOOK_INPUT=$(cat)
}

# Detect which host invoked this hook. Claude Code sets CLAUDE_PLUGIN_ROOT
# in the hook environment; Cursor does not.
detect_platform() {
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    echo claude
  else
    echo cursor
  fi
}

# Extract a string field from JSON. Accepts dotted paths
# (e.g. "tool_input.command") and array indexes (e.g. "workspace_roots[0]")
# when jq is available; falls back to top-level-only grep/sed when jq is
# missing.
# Usage: json_field "fieldName" [json_string]
json_field() {
  local field="$1"
  local input="${2:-${HOOK_INPUT:-}}"
  if command -v jq &>/dev/null; then
    echo "$input" | jq -r ".${field} // empty" 2>/dev/null || true
  else
    # Fallback: top-level string fields only. Dotted paths (Claude's
    # nested tool_input.command) require jq.
    local leaf="${field##*.}"
    echo "$input" | grep -o "\"${leaf}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed "s/\"${leaf}\"[[:space:]]*:[[:space:]]*\"//" | sed 's/"$//' || true
  fi
}

# Encode a string as a JSON string literal (including the quotes).
json_string() {
  if command -v jq &>/dev/null; then
    printf '%s' "$1" | jq -Rs .
  else
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '"%s"' "$s"
  fi
}

# Resolve the consuming project's root directory. The hook process's own
# working directory is not reliable (on Cursor it may be the plugin
# directory), so prefer what the host tells us:
#   1. payload `cwd` (Claude Code: every event; Cursor: shell events)
#   2. CLAUDE_PROJECT_DIR (Claude Code: session start directory)
#   3. payload `workspace_roots[0]` (Cursor: every event)
#   4. git toplevel of the hook's working directory
# A git toplevel is taken from whichever directory is found first, so a
# session inside a feature worktree resolves to that worktree.
project_root() {
  local dir=""
  dir=$(json_field "cwd")
  [[ -z "$dir" ]] && dir="${CLAUDE_PROJECT_DIR:-}"
  [[ -z "$dir" ]] && dir=$(json_field "workspace_roots[0]")
  [[ -z "$dir" || ! -d "$dir" ]] && dir=$(pwd)
  git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir"
}

# Emit context for the model in the shape each host expects.
# Usage: emit_context <claude-event-name> <message>
#   Claude Code: hookSpecificOutput.additionalContext (SessionStart, Stop, ...)
#   Cursor:      sessionStart → additional_context; stop → followup_message
#                (note: a Cursor followup_message is auto-submitted as the
#                next user turn, so never emit one from stop casually)
emit_context() {
  local event="$1"
  local msg
  msg=$(json_string "$2")
  if [[ "$(detect_platform)" == "claude" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":%s}}\n' "$event" "$msg"
  else
    case "$event" in
      SessionStart) printf '{"additional_context":%s}\n' "$msg" ;;
      Stop)         printf '{"followup_message":%s}\n' "$msg" ;;
      *)            printf '{"additional_context":%s}\n' "$msg" ;;
    esac
  fi
}

# Locate the active progress file: in the project root itself (a session
# inside the feature worktree), or via the .darwin/active-worktree
# breadcrumb left at the main checkout root. Prints nothing if none.
# Usage: find_progress_file <root>
find_progress_file() {
  local root="$1" wt=""
  if [[ -f "$root/.darwin/darwin-progress.md" ]]; then
    echo "$root/.darwin/darwin-progress.md"
  elif [[ -f "$root/.darwin/active-worktree" ]]; then
    wt=$(cat "$root/.darwin/active-worktree" 2>/dev/null || true)
    if [[ -n "$wt" && -f "$wt/.darwin/darwin-progress.md" ]]; then
      echo "$wt/.darwin/darwin-progress.md"
    fi
  fi
}

# True if the progress file's task table has any unfinished row. Matches the
# Status cell (last column) of table rows only, so the status legend in
# prose never counts.
has_unfinished_tasks() {
  grep -qE '^\|.*\|[[:space:]]*(PENDING|IN_PROGRESS|DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED)[[:space:]]*\|[[:space:]]*$' "$1" 2>/dev/null
}

# True if the progress file is a plan still being drafted: it sits in the main
# checkout (where .git is a directory, not a worktree's .git file) and its
# Overview records no Worktree yet. Plan finalization records the Worktree,
# so there is nothing to resume before that.
# Usage: is_draft_progress <progress-file> <root>
is_draft_progress() {
  local file="$1" root="$2"
  [[ -d "$root/.git" && "$file" == "$root/.darwin/darwin-progress.md" ]] || return 1
  ! grep -qE '^[^|]*Worktree[^|:]*:[[:space:]*`]*[^[:space:]*`]' "$file" 2>/dev/null
}
