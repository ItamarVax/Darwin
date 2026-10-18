#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

read_stdin

ROOT=$(project_root)
SESSION_ID=$(json_field "session_id")
[[ -z "$SESSION_ID" ]] && SESSION_ID=$(json_field "conversation_id")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Write the pending-session marker only when there is something to learn
# from: a learnings directory exists AND an execution plan is active.
# (Writing it unconditionally made session-start ask for /compound forever.)
# Darwin 5 keeps learnings in .darwin/learnings/; the legacy
# .cursor/darwin-learnings/ is used until compound migrates it.
LEARNINGS=""
if [[ -d "$ROOT/.darwin/learnings" ]]; then
  LEARNINGS="$ROOT/.darwin/learnings"
elif [[ -d "$ROOT/.cursor/darwin-learnings" ]]; then
  LEARNINGS="$ROOT/.cursor/darwin-learnings"
fi
if [[ -n "$LEARNINGS" && -n "$(find_progress_file "$ROOT")" ]]; then
  printf '{"session_id": %s, "ended_at": "%s"}\n' "$(json_string "$SESSION_ID")" "$TIMESTAMP" \
    > "$LEARNINGS/.pending-session"
fi

exit 0
