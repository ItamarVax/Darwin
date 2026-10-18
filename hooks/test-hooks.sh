#!/usr/bin/env bash
# Regression checks for Darwin hooks. Pipes sample payloads for both hosts
# (Claude Code and Cursor) through every hook and checks exit codes and
# output shape. Run after any hook change:  bash hooks/test-hooks.sh
# Requires: bash, git, jq.

set -uo pipefail

HOOKS="$(cd "$(dirname "$0")" && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

# run_hook <claude|cursor> <script> <payload-json>  → sets OUT, RC
run_hook() {
  local platform="$1" script="$2" payload="$3"
  if [[ "$platform" == "claude" ]]; then
    OUT=$(cd "$TMP" && printf '%s' "$payload" | CLAUDE_PLUGIN_ROOT="$HOOKS/.." bash "$HOOKS/$script" 2>/dev/null)
  else
    OUT=$(cd "$TMP" && printf '%s' "$payload" | env -u CLAUDE_PLUGIN_ROOT -u CLAUDE_PROJECT_DIR bash "$HOOKS/$script" 2>/dev/null)
  fi
  RC=$?
}

shell_payload() {
  local platform="$1" cmd
  cmd=$(printf '%s' "$2" | jq -Rs .)
  if [[ "$platform" == "claude" ]]; then
    printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":"%s"}' "$cmd" "$PROJ"
  else
    printf '{"command":%s,"cwd":"%s","workspace_roots":["%s"]}' "$cmd" "$PROJ" "$PROJ"
  fi
}

session_payload() {
  if [[ "$1" == "claude" ]]; then
    printf '{"session_id":"s-1","cwd":"%s","hook_event_name":"SessionStart"}' "$PROJ"
  else
    printf '{"conversation_id":"c-1","workspace_roots":["%s"]}' "$PROJ"
  fi
}

# context_text <platform>  → extracts the injected message from OUT
context_text() {
  if [[ "$1" == "claude" ]]; then
    printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
  else
    printf '%s' "$OUT" | jq -r '.additional_context // empty' 2>/dev/null
  fi
}

# quiet <platform>  → true if OUT carries no priority message (the Claude-only
# onboarded-repo hint alone counts as quiet)
quiet() {
  [[ -z "$OUT" || "$(context_text "$1")" == "This repository uses the Darwin workflow plugin."* ]]
}

new_project() {
  PROJ="$TMP/proj-$RANDOM$RANDOM"
  mkdir -p "$PROJ"
  git -C "$PROJ" init -q
}

# ── before-shell ──────────────────────────────────────────────────────
BLOCKED=(
  'rm -rf /'
  'rm -rf / '
  'rm -fr /'
  'rm -Rf ~'
  'rm -r -f $HOME'
  'sudo rm -rf /*'
  'rm --recursive --force .'
  'cd x && rm -rf ~/'
  'git push --force'
  'git push -f origin main'
  'git push origin +main'
  'git push -uf origin feat'
  'git -C /x push --force origin main'
  'git -c core.x=y push -f'
  'dd if=/dev/zero of=/dev/sda'
  'echo x > /dev/nvme0n1'
  'mkfs.ext4 /dev/sdb1'
)
ALLOWED=(
  'rm -rf /tmp/build'
  'rm -rf ./dist'
  'rm -rf node_modules'
  'rm -f /tmp/x.log'
  'rm -r docs/old'
  'git push --force-with-lease'
  'git push origin feat/x'
  'git push -u origin feat/x'
  'git -C /x push origin main'
  'git log --grep push --force-with-lease'
  'git reset --hard HEAD~1'
  'ls -la /'
  'echo "rm -rf /" > notes.txt'
)
new_project
for platform in claude cursor; do
  for c in "${BLOCKED[@]}"; do
    run_hook "$platform" before-shell.sh "$(shell_payload "$platform" "$c")"
    if [[ $RC -eq 2 ]]; then ok; else fail "[$platform] should block: $c (rc=$RC)"; fi
    if [[ "$platform" == "cursor" ]]; then
      if [[ "$(printf '%s' "$OUT" | jq -r '.permission' 2>/dev/null)" == "deny" ]]; then ok; else fail "[cursor] deny JSON missing: $c"; fi
    fi
  done
  for c in "${ALLOWED[@]}"; do
    run_hook "$platform" before-shell.sh "$(shell_payload "$platform" "$c")"
    if [[ $RC -eq 0 ]]; then ok; else fail "[$platform] should allow: $c (rc=$RC)"; fi
  done
done

# ── session-start ─────────────────────────────────────────────────────
for platform in claude cursor; do
  # Not onboarded: reminder once per repo, then silent.
  new_project
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if [[ "$(context_text "$platform")" == *"Set up Darwin"* ]]; then ok; else fail "[$platform] onboarding reminder missing: $OUT"; fi
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if [[ -z "$OUT" ]]; then ok; else fail "[$platform] onboarding reminder repeated: $OUT"; fi

  # Onboarded, unfinished task row → /resume.
  mkdir -p "$PROJ/.cursor/rules" "$PROJ/.darwin"
  touch "$PROJ/.cursor/rules/project-context.mdc"
  echo '{"commands":{"test":"true"}}' > "$PROJ/.darwin/config.json"
  cat > "$PROJ/.darwin/darwin-progress.md" <<'MD'
- **Worktree**: /tmp/wt
Status legend: PENDING/IN_PROGRESS/COMPLETE

| ID | Task | File(s) | Depends on | Status |
|----|------|---------|------------|--------|
| 1 | A | a.sh | — | COMPLETE |
| 2 | B | b.sh | 1 | DONE |
MD
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if [[ "$(context_text "$platform")" == *"/resume"* ]]; then ok; else fail "[$platform] resume reminder missing: $OUT"; fi

  # All tasks complete; legend text alone must not trigger /resume.
  sed -i.bak 's/| DONE |/| COMPLETE |/' "$PROJ/.darwin/darwin-progress.md"
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if quiet "$platform"; then ok; else fail "[$platform] legend text triggered a reminder: $OUT"; fi

  # Pending learnings → /compound.
  mkdir -p "$PROJ/.cursor/darwin-learnings"
  echo '{}' > "$PROJ/.cursor/darwin-learnings/.pending-session"
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if [[ "$(context_text "$platform")" == *"/compound"* ]]; then ok; else fail "[$platform] compound reminder missing: $OUT"; fi

  # Not onboarded, reminder already shown: resume still detected.
  new_project
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  mkdir -p "$PROJ/.darwin"
  printf -- '- **Worktree**: /tmp/wt\n| 1 | A | a | — | IN_PROGRESS |\n' > "$PROJ/.darwin/darwin-progress.md"
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if [[ "$(context_text "$platform")" == *"/resume"* ]]; then ok; else fail "[$platform] resume skipped in non-onboarded repo: $OUT"; fi

  # Onboarded with Darwin 4 (no commands in config) → v5 setup suggested once.
  new_project
  mkdir -p "$PROJ/.cursor/rules" "$PROJ/.darwin"
  touch "$PROJ/.cursor/rules/project-context.mdc"
  echo '{"profile":"balanced"}' > "$PROJ/.darwin/config.json"
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if [[ "$(context_text "$platform")" == *"Set up Darwin 5"* ]]; then ok; else fail "[$platform] v5 setup suggestion missing: $OUT"; fi
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if quiet "$platform"; then ok; else fail "[$platform] v5 setup suggestion repeated: $OUT"; fi

  # v5 suggestion never hides an interrupted execution.
  new_project
  mkdir -p "$PROJ/.cursor/rules" "$PROJ/.darwin"
  touch "$PROJ/.cursor/rules/project-context.mdc"
  printf -- '- **Worktree**: /tmp/wt\n| 1 | A | a | — | PENDING |\n' > "$PROJ/.darwin/darwin-progress.md"
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if [[ "$(context_text "$platform")" == *"/resume"* ]]; then ok; else fail "[$platform] v5 suggestion preempted resume: $OUT"; fi

  # Commands present → no v5 suggestion.
  new_project
  mkdir -p "$PROJ/.cursor/rules" "$PROJ/.darwin"
  touch "$PROJ/.cursor/rules/project-context.mdc"
  echo '{"commands":{"test":"pytest"}}' > "$PROJ/.darwin/config.json"
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if quiet "$platform"; then ok; else fail "[$platform] v5 suggestion despite commands: $OUT"; fi

  # Draft plan in the main checkout (no Worktree recorded) → no /resume.
  new_project
  mkdir -p "$PROJ/.cursor/rules" "$PROJ/.darwin"
  touch "$PROJ/.cursor/rules/project-context.mdc"
  echo '{"commands":{"test":"true"}}' > "$PROJ/.darwin/config.json"
  printf -- '- **Worktree**:\n| 1 | A | a | — | PENDING |\n' > "$PROJ/.darwin/darwin-progress.md"
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if [[ "$(context_text "$platform")" != *"/resume"* ]]; then ok; else fail "[$platform] resume suggested for a draft plan: $OUT"; fi

  # Onboarded repo: Claude gets the factual Darwin hint, Cursor does not.
  new_project
  mkdir -p "$PROJ/.cursor/rules" "$PROJ/.darwin"
  touch "$PROJ/.cursor/rules/project-context.mdc"
  echo '{"commands":{"test":"true"}}' > "$PROJ/.darwin/config.json"
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if [[ "$platform" == "claude" ]]; then
    if [[ "$(context_text claude)" == *"darwin:systematic-debugging"* ]]; then ok; else fail "[claude] onboarded hint missing: $OUT"; fi
  else
    if [[ -z "$OUT" ]]; then ok; else fail "[cursor] unexpected hint: $OUT"; fi
  fi
  # Hint is combined with a priority message, not replacing it.
  printf -- '- **Worktree**: /tmp/wt\n| 1 | A | a | — | PENDING |\n' > "$PROJ/.darwin/darwin-progress.md"
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if [[ "$platform" == "claude" ]]; then
    t=$(context_text claude)
    if [[ "$t" == *"/resume"* && "$t" == *"darwin:quick"* ]]; then ok; else fail "[claude] hint not combined with resume: $OUT"; fi
  else
    if [[ "$(context_text cursor)" != *"darwin:quick"* ]]; then ok; else fail "[cursor] hint leaked: $OUT"; fi
  fi

  # Breadcrumb → progress file in another worktree.
  new_project
  mkdir -p "$PROJ/.cursor/rules" "$PROJ/.darwin" "$TMP/wt-$platform/.darwin"
  touch "$PROJ/.cursor/rules/project-context.mdc"
  echo "$TMP/wt-$platform" > "$PROJ/.darwin/active-worktree"
  printf '| 1 | A | a | — | BLOCKED |\n' > "$TMP/wt-$platform/.darwin/darwin-progress.md"
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if [[ "$(context_text "$platform")" == *"/resume"* ]]; then ok; else fail "[$platform] breadcrumb resume missing: $OUT"; fi
done

# Pending learnings in the Darwin 5 location → /compound.
for platform in claude cursor; do
  new_project
  mkdir -p "$PROJ/.cursor/rules" "$PROJ/.darwin/learnings"
  touch "$PROJ/.cursor/rules/project-context.mdc"
  echo '{"commands":{"test":"true"}}' > "$PROJ/.darwin/config.json"
  echo '{}' > "$PROJ/.darwin/learnings/.pending-session"
  run_hook "$platform" session-start.sh "$(session_payload "$platform")"
  if [[ "$(context_text "$platform")" == *"/compound"* ]]; then ok; else fail "[$platform] v5 compound reminder missing: $OUT"; fi
done

# ── session-end ───────────────────────────────────────────────────────
for platform in claude cursor; do
  # Darwin 5 location: marker goes to .darwin/learnings/.
  new_project
  mkdir -p "$PROJ/.darwin/learnings"
  printf '| 1 | A | a | — | COMPLETE |\n' > "$PROJ/.darwin/darwin-progress.md"
  run_hook "$platform" session-end.sh "$(session_payload "$platform")"
  if jq -e . "$PROJ/.darwin/learnings/.pending-session" >/dev/null 2>&1; then ok; else fail "[$platform] v5 marker missing or invalid JSON"; fi

  new_project
  mkdir -p "$PROJ/.cursor/darwin-learnings"
  run_hook "$platform" session-end.sh "$(session_payload "$platform")"
  if [[ ! -f "$PROJ/.cursor/darwin-learnings/.pending-session" ]]; then ok; else fail "[$platform] marker written without a plan"; fi

  mkdir -p "$PROJ/.darwin"
  printf '| 1 | A | a | — | COMPLETE |\n' > "$PROJ/.darwin/darwin-progress.md"
  run_hook "$platform" session-end.sh "$(session_payload "$platform")"
  if jq -e . "$PROJ/.cursor/darwin-learnings/.pending-session" >/dev/null 2>&1; then ok; else fail "[$platform] marker missing or invalid JSON"; fi
done

# ── hook configs ──────────────────────────────────────────────────────
for cfg in hooks.json hooks-cursor.json; do
  if jq -e . "$HOOKS/$cfg" >/dev/null 2>&1; then ok; else fail "$cfg is not valid JSON"; fi
  for script in $(jq -r '.. | .command? // empty' "$HOOKS/$cfg" | sed -E 's|.*/hooks/||'); do
    if [[ -f "$HOOKS/$script" ]]; then ok; else fail "$cfg references missing $script"; fi
  done
done

echo "hooks: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
