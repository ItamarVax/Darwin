#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

read_stdin

ROOT=$(project_root)

# Priority 1: Missing onboarding — suggested once per repository, so a
# globally installed plugin doesn't nag in every repo on every session.
# The marker lives in the git common dir: untracked, shared by worktrees.
if [[ ! -f "$ROOT/.cursor/rules/project-context.mdc" ]]; then
  GIT_DIR=$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null || true)
  if [[ -n "$GIT_DIR" ]]; then
    [[ "$GIT_DIR" != /* ]] && GIT_DIR="$ROOT/$GIT_DIR"
    MARKER="$GIT_DIR/darwin-onboarding-suggested"
    if [[ ! -f "$MARKER" ]]; then
      touch "$MARKER" 2>/dev/null || true
      emit_context SessionStart "Darwin hasn't been set up for this project yet. If the user wants Darwin here, suggest: \"Set up Darwin for this project\" (onboarding). This reminder is shown once per repository."
      exit 0
    fi
  fi
  # Reminder already shown (or not a git repo): fall through, so resume and
  # compound reminders still work in repos that skipped onboarding.
fi

# Claude Code has no alwaysApply rule, so plain requests would bypass Darwin.
# In onboarded repos, state the facts once per session start (Cursor gets the
# same from rules/framework.mdc). Combined with any priority message below.
HINT=""
if [[ "$(detect_platform)" == "claude" && -f "$ROOT/.cursor/rules/project-context.mdc" ]]; then
  HINT="This repository uses the Darwin workflow plugin. For code changes, Darwin's skills apply: darwin:quick for small changes, darwin:systematic-debugging for bugs, darwin:research then darwin:plan for features; the darwin:using-darwin skill describes the workflow. Behavior files in .darwin/behaviors/ are kept in sync with the code by a drift check."
fi

# Emit the priority message, followed by the hint when there is one.
emit() {
  if [[ -n "$HINT" ]]; then
    emit_context SessionStart "$1 $HINT"
  else
    emit_context SessionStart "$1"
  fi
}

# Priority 2: Incomplete execution — suggest /resume
PROGRESS=$(find_progress_file "$ROOT")
if [[ -n "$PROGRESS" ]] && has_unfinished_tasks "$PROGRESS" && ! is_draft_progress "$PROGRESS" "$ROOT"; then
  emit "There's an incomplete Darwin execution from a previous session ($PROGRESS). Suggest \`/resume\` to pick up where it left off."
  exit 0
fi

# Priority 3: Pending compound learning
if [[ -f "$ROOT/.darwin/learnings/.pending-session" || -f "$ROOT/.cursor/darwin-learnings/.pending-session" ]]; then
  emit "The previous Darwin session has uncaptured learnings. Suggest \`/compound\` to capture them."
  exit 0
fi

# Priority 4: Onboarded with Darwin 4 but missing the Darwin 5 setup (test
# commands, behaviors) — suggested once per repository. Lowest priority so it
# never hides an interrupted execution or pending learnings. Needs jq to read
# the config; without it, stay silent rather than guess.
if [[ -f "$ROOT/.cursor/rules/project-context.mdc" ]] && command -v jq >/dev/null 2>&1; then
  CONFIG="$ROOT/.darwin/config.json"
  if [[ ! -f "$CONFIG" ]] || ! jq -e '.commands | type == "object"' "$CONFIG" >/dev/null 2>&1; then
    GIT_DIR=$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null || true)
    if [[ -n "$GIT_DIR" ]]; then
      [[ "$GIT_DIR" != /* ]] && GIT_DIR="$ROOT/$GIT_DIR"
      MARKER="$GIT_DIR/darwin-v5-onboarding-suggested"
      if [[ ! -f "$MARKER" ]]; then
        touch "$MARKER" 2>/dev/null || true
        emit "This project was onboarded with an earlier Darwin version and has no test commands or behavior files in .darwin/config.json. If the user wants them, suggest running onboarding and choosing \"Set up Darwin 5 (commands, tests, behaviors)\". This reminder is shown once per repository."
        exit 0
      fi
    fi
  fi
fi

[[ -n "$HINT" ]] && emit_context SessionStart "$HINT"
exit 0
