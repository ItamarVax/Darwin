#!/usr/bin/env bash
# behavior-check.sh — Darwin's strict drift check for behavior files.
#
# Compares the files a branch changed against .darwin/behaviors/*.md and
# fails when covered code changed without its behavior file being updated (or
# a "Behavior-Change: none (<capability>) — <reason>" commit trailer), when
# behavior files are internally inconsistent, or — on branches that carry a
# change proposal — when changed code is covered by no behavior file.
#
# Formats: skills/behaviors/references/formats.md (the single definition).
# Config:  .darwin/config.json — behaviors.enabled, behaviors.strictUncovered,
#          behaviors.ignore (see the execute skill's Darwin Config section).
#
# Usage (from the project or worktree root):
#   behavior-check.sh [--base <ref>] [--staged] [--quiet]
#
#   --base <ref>  Compare against <ref> instead of the resolved base.
#   --staged      Also check staged changes. A pending commit message can be
#                 supplied via the DARWIN_COMMIT_MSG_FILE environment variable
#                 so its Behavior-Change trailers count.
#   --quiet       Print only ERROR and WARN lines.
#
# Exit codes: 0 pass (warnings may be printed), 1 violations,
#             2 usage or environment error.
#
# Portable to bash 3.2 (macOS default): no associative arrays or mapfile.

set -uo pipefail

BASE_REF=""
STAGED=0
QUIET=0

usage() {
  echo "usage: behavior-check.sh [--base <ref>] [--staged] [--quiet]" >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --base) [ $# -ge 2 ] || usage; BASE_REF="$2"; shift 2 ;;
    --staged) STAGED=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage ;;
    *) echo "behavior-check: unknown argument '$1'" >&2; usage ;;
  esac
done

info() { [ "$QUIET" -eq 1 ] || echo "behavior-check: $*"; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "behavior-check: not inside a git repository." >&2
  exit 2
}
cd "$ROOT" || exit 2

CONFIG=".darwin/config.json"
BEHAVIORS_DIR=".darwin/behaviors"
ERRORS=0
WARNINGS=0

error() { ERRORS=$((ERRORS + 1)); echo "ERROR $*"; }
warn()  { WARNINGS=$((WARNINGS + 1)); echo "WARN  $*"; }

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
ENABLED="true"
STRICT_UNCOVERED="false"
EXTRA_IGNORE=""

if [ -f "$CONFIG" ]; then
  if command -v jq >/dev/null 2>&1; then
    if ! jq -e . "$CONFIG" >/dev/null 2>&1; then
      echo "behavior-check: $CONFIG is not valid JSON." >&2
      exit 2
    fi
    ENABLED="$(jq -r 'if .behaviors.enabled == false then "false" else "true" end' "$CONFIG")"
    STRICT_UNCOVERED="$(jq -r 'if .behaviors.strictUncovered == true then "true" else "false" end' "$CONFIG")"
    EXTRA_IGNORE="$(jq -r '(.behaviors.ignore // []) | .[]' "$CONFIG" 2>/dev/null | tr '\n' ' ')"
  else
    warn "jq not found — ignoring $CONFIG and using defaults (enabled, strictUncovered=false)"
  fi
fi

if [ "$ENABLED" != "true" ]; then
  info "behaviors.enabled is false — nothing to check."
  exit 0
fi
if [ ! -d "$BEHAVIORS_DIR" ]; then
  info "no $BEHAVIORS_DIR/ — nothing to check."
  exit 0
fi

# ---------------------------------------------------------------------------
# Base resolution
# ---------------------------------------------------------------------------
resolve_base() {
  local candidate
  if [ -n "$BASE_REF" ]; then
    git rev-parse --verify -q "$BASE_REF^{commit}" >/dev/null || {
      echo "behavior-check: --base '$BASE_REF' is not a valid commit." >&2
      exit 2
    }
    git merge-base HEAD "$BASE_REF" 2>/dev/null || echo "$BASE_REF"
    return
  fi
  if [ -f .darwin/darwin-progress.md ]; then
    candidate="$(grep -m1 -E '^[[:space:]]*[-*]*[[:space:]]*\**Base\**[[:space:]]*:' .darwin/darwin-progress.md \
      | sed -E 's/^[^:]*:[[:space:]]*//; s/[`*]//g' | awk '{print $1}')"
    if [ -n "$candidate" ] && git rev-parse --verify -q "$candidate^{commit}" >/dev/null; then
      git merge-base HEAD "$candidate" 2>/dev/null && return
    fi
  fi
  # Without an explicit base, use the newest merge base among the default
  # branch candidates — a local main with unpushed commits (e.g. onboarding's
  # behavior files) must win over a stale origin/HEAD.
  local best="" best_count=-1 mb count
  for candidate in origin/HEAD main master; do
    if git rev-parse --verify -q "$candidate^{commit}" >/dev/null; then
      mb="$(git merge-base HEAD "$candidate" 2>/dev/null)" || continue
      count="$(git rev-list --count "$mb")"
      if [ "$count" -gt "$best_count" ]; then best="$mb"; best_count="$count"; fi
    fi
  done
  if [ -n "$best" ]; then
    echo "$best"
    return
  fi
  echo "behavior-check: cannot resolve a base ref (no --base, no Base: in the progress file, no origin/HEAD, main, or master)." >&2
  exit 2
}
BASE="$(resolve_base)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
# Changed files and commit messages
# ---------------------------------------------------------------------------
git diff --name-only --diff-filter=d "$BASE"...HEAD > "$TMP/changed_raw" 2>/dev/null
if [ "$STAGED" -eq 1 ]; then
  git diff --name-only --cached --diff-filter=d >> "$TMP/changed_raw" 2>/dev/null
fi
sort -u "$TMP/changed_raw" > "$TMP/changed_all"

{
  git log --format=%B "$BASE"..HEAD 2>/dev/null
  if [ "$STAGED" -eq 1 ] && [ -n "${DARWIN_COMMIT_MSG_FILE:-}" ] && [ -f "$DARWIN_COMMIT_MSG_FILE" ]; then
    cat "$DARWIN_COMMIT_MSG_FILE"
  fi
} > "$TMP/messages"

# A branch carries a change proposal when it added .darwin/proposal.md or an
# archived copy — that marks it as feature-track work.
HAS_PROPOSAL=0
git log --diff-filter=A --name-only --format= "$BASE"..HEAD > "$TMP/added" 2>/dev/null
if [ "$STAGED" -eq 1 ]; then
  git diff --name-only --cached --diff-filter=A >> "$TMP/added" 2>/dev/null
fi
if grep -qE '^\.darwin/(proposal\.md|archive/[^/]+/proposal\.md)$' "$TMP/added"; then
  HAS_PROPOSAL=1
fi

# ---------------------------------------------------------------------------
# Path matching
# ---------------------------------------------------------------------------
# Capability paths are anchored at the repo root:
#   "src/export/"    directory prefix
#   "src/api.py"     exact file (or directory of that name)
#   "src/**/x.py"    glob; * and ** both cross "/"
matches_capability_path() {
  local f="$1" p="$2" g
  case "$p" in
    *'*'*)
      g="${p//\*\*/*}"
      # shellcheck disable=SC2053
      [[ "$f" == $g ]] || [[ "$f" == $g/* ]]
      ;;
    */) [[ "$f" == "$p"* ]] ;;
    *) [[ "$f" == "$p" || "$f" == "$p"/* ]] ;;
  esac
}

# Ignore patterns match anywhere in the tree:
#   "tests/"      any path component named tests
#   "*.test.*"    a pattern without "/" matches the basename
#   "a/b/*.py"    a pattern with "/" matches the whole path
DEFAULT_IGNORE=".darwin/ .cursor/ .claude/ .worktrees/ .github/ .gitlab/ tests/ test/ __tests__/ spec/ docs/ *.md test_*.py *_test.py *_test.go conftest.py *.test.* *.spec.* .gitignore .gitlab-ci.yml"
is_ignored() {
  local f="$1" p g base
  base="${f##*/}"
  for p in $DEFAULT_IGNORE $EXTRA_IGNORE; do
    case "$p" in
      */)
        [[ "/$f" == */"${p%/}"/* ]] && return 0
        ;;
      */*)
        g="${p//\*\*/*}"
        # shellcheck disable=SC2053
        [[ "$f" == $g ]] && return 0
        ;;
      *)
        # shellcheck disable=SC2053
        [[ "$base" == $p ]] && return 0
        ;;
    esac
  done
  return 1
}

# ---------------------------------------------------------------------------
# Parse behavior files
# ---------------------------------------------------------------------------
: > "$TMP/caps"      # capability<TAB>file
: > "$TMP/paths"     # capability<TAB>path
: > "$TMP/reqs"      # id<TAB>file<TAB>status<TAB>tests<TAB>has_tests_line

for bf in "$BEHAVIORS_DIR"/*.md; do
  [ -f "$bf" ] || continue
  expected="$(basename "$bf" .md)"

  frontmatter="$(awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {exit} fm {print}' "$bf")"
  if [ -z "$frontmatter" ]; then
    error "$bf: missing YAML frontmatter (capability, paths)"
    continue
  fi
  cap="$(printf '%s\n' "$frontmatter" | sed -nE 's/^capability:[[:space:]]*["'"'"']?([^"'"'"']*)["'"'"']?[[:space:]]*$/\1/p' | head -1)"
  if [ -z "$cap" ]; then
    error "$bf: frontmatter has no 'capability'"
    continue
  fi
  if [ "$cap" != "$expected" ]; then
    error "$bf: capability '$cap' does not match the file name '$expected'"
  fi
  printf '%s\t%s\n' "$cap" "$bf" >> "$TMP/caps"

  printf '%s\n' "$frontmatter" | awk -v q="'" '
    /^paths:/ {
      v = $0; sub(/^paths:[ \t]*/, "", v)
      if (v ~ /^\[/) {
        gsub(/[\[\]]/, "", v)
        n = split(v, arr, ",")
        for (i = 1; i <= n; i++) {
          p = arr[i]; gsub(/"/, "", p); gsub(q, "", p)
          gsub(/^[ \t]+|[ \t]+$/, "", p)
          if (p != "") print p
        }
        inblock = 0
      } else {
        inblock = 1
      }
      next
    }
    inblock && /^[ \t]*-[ \t]*/ {
      p = $0; sub(/^[ \t]*-[ \t]*/, "", p); gsub(/"/, "", p); gsub(q, "", p)
      gsub(/[ \t]+$/, "", p)
      if (p != "") print p
      next
    }
    inblock { inblock = 0 }
  ' | while IFS= read -r p; do printf '%s\t%s\n' "$cap" "$p"; done >> "$TMP/paths"

  if ! grep -q "^$cap$(printf '\t')" "$TMP/paths"; then
    error "$bf: frontmatter 'paths' is empty"
  fi

  awk -v F="$bf" '
    function emit() { printf "%s\t%s\t%s\t%s\t%d\n", id, F, status, tests, hastests }
    /^### [A-Z0-9][A-Z0-9-]*-[0-9]+:/ {
      if (id != "") emit()
      line = $0; sub(/^### /, "", line); sub(/:.*/, "", line)
      id = line; status = ""; tests = ""; hastests = 0
      next
    }
    /^#+ / { if (id != "") emit(); id = ""; next }
    id != "" && /^Status:/ { s = $0; sub(/^Status:[ \t]*/, "", s); sub(/[ \t]+$/, "", s); status = s; next }
    id != "" && /^Tests:/  { t = $0; sub(/^Tests:[ \t]*/, "", t); sub(/[ \t]+$/, "", t); tests = t; hastests = 1; next }
    END { if (id != "") emit() }
  ' "$bf" >> "$TMP/reqs"
done

# ---------------------------------------------------------------------------
# Rule 2 — integrity
# ---------------------------------------------------------------------------
cut -f1 "$TMP/reqs" | sort | uniq -d | while IFS= read -r dup; do
  echo "$dup"
done > "$TMP/dups"
while IFS= read -r dup; do
  [ -n "$dup" ] || continue
  where="$(awk -F'\t' -v d="$dup" '$1 == d {print $2}' "$TMP/reqs" | tr '\n' ' ')"
  error "requirement ID $dup is used more than once ($where) — IDs are permanent and never reused; take the next free number"
done < "$TMP/dups"

while IFS="$(printf '\t')" read -r id bf status tests hastests; do
  [ -n "$id" ] || continue
  cap="$(basename "$bf" .md)"
  want_prefix="$(printf '%s' "$cap" | tr '[:lower:]' '[:upper:]')"
  if [ "${id%-*}" != "$want_prefix" ]; then
    error "$bf: $id does not use the capability prefix $want_prefix-"
  fi
  case "$status" in
    intended)
      if [ "$hastests" -ne 1 ] || [ -z "$tests" ] || [ "$tests" = "none yet" ]; then
        error "$bf: $id is intended but has no test pointer — add 'Tests: <path>::<name>' or set it back to observed"
        continue
      fi
      ;;
    observed)
      if [ "$hastests" -ne 1 ] || [ -z "$tests" ]; then
        error "$bf: $id has no 'Tests:' line — use test pointers or 'Tests: none yet'"
        continue
      fi
      [ "$tests" = "none yet" ] && continue
      ;;
    removed)
      if [ "$hastests" -eq 1 ]; then
        error "$bf: $id is removed but still has a 'Tests:' line — tombstones carry only Status and Reason"
      fi
      continue
      ;;
    "")
      error "$bf: $id has no 'Status:' line (intended | observed | removed)"
      continue
      ;;
    *)
      error "$bf: $id has unknown status '$status' (intended | observed | removed)"
      continue
      ;;
  esac
  # Resolve each test pointer: <path>::<name>, comma-separated. A comma only
  # starts a new pointer when the next piece contains "::", so test titles
  # that contain commas (Jest, RSpec) stay whole. The name checked is the
  # last "::" segment, so pytest class nodes (path::TestX::test_y) work.
  printf '%s\n' "$tests" | awk '
    {
      n = split($0, parts, ",")
      cur = ""
      for (i = 1; i <= n; i++) {
        if (cur != "" && parts[i] ~ /::/) { print cur; cur = parts[i] }
        else if (cur == "") { cur = parts[i] }
        else { cur = cur "," parts[i] }
      }
      if (cur != "") print cur
    }' | while IFS= read -r ptr; do
    ptr="$(printf '%s' "$ptr" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [ -n "$ptr" ] || continue
    case "$ptr" in
      *::*) ;;
      *) echo "ERROR $bf: $id test pointer '$ptr' is not '<path>::<name>'"; continue ;;
    esac
    tpath="${ptr%%::*}"
    tname="${ptr##*::}"
    if [ ! -f "$tpath" ]; then
      echo "ERROR $bf: $id points at '$tpath', which does not exist"
    elif ! grep -qF -- "$tname" "$tpath"; then
      echo "ERROR $bf: $id points at '$tname' in $tpath, which does not contain it"
    fi
  done >> "$TMP/pointer_errors"
done < "$TMP/reqs"

if [ -s "$TMP/pointer_errors" ]; then
  cat "$TMP/pointer_errors"
  ERRORS=$((ERRORS + $(wc -l < "$TMP/pointer_errors")))
fi

# ---------------------------------------------------------------------------
# Rules 1 and 3 — covered and uncovered changes
# ---------------------------------------------------------------------------
: > "$TMP/touched_caps"
: > "$TMP/uncovered"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  is_ignored "$f" && continue
  covered=0
  while IFS="$(printf '\t')" read -r cap p; do
    [ -n "$cap" ] || continue
    if matches_capability_path "$f" "$p"; then
      echo "$cap" >> "$TMP/touched_caps"
      covered=1
    fi
  done < "$TMP/paths"
  [ "$covered" -eq 1 ] || echo "$f" >> "$TMP/uncovered"
done < "$TMP/changed_all"

sort -u "$TMP/touched_caps" | while IFS= read -r cap; do
  [ -n "$cap" ] || continue
  if grep -qxF "$BEHAVIORS_DIR/$cap.md" "$TMP/changed_all"; then
    continue
  fi
  if grep -qF "Behavior-Change: none ($cap)" "$TMP/messages"; then
    continue
  fi
  echo "ERROR capability '$cap': covered code changed but $BEHAVIORS_DIR/$cap.md was not updated. Update it, or — if behavior did not change — add the commit trailer: Behavior-Change: none ($cap) — <reason>"
done > "$TMP/rule1_errors"
if [ -s "$TMP/rule1_errors" ]; then
  cat "$TMP/rule1_errors"
  ERRORS=$((ERRORS + $(wc -l < "$TMP/rule1_errors")))
fi

if [ -s "$TMP/uncovered" ]; then
  count="$(wc -l < "$TMP/uncovered" | tr -d ' ')"
  list="$(head -10 "$TMP/uncovered" | tr '\n' ' ')"
  [ "$count" -gt 10 ] && list="$list(and $((count - 10)) more)"
  if [ "$HAS_PROPOSAL" -eq 1 ] || [ "$STRICT_UNCOVERED" = "true" ]; then
    error "$count changed file(s) are covered by no behavior file: ${list}— the change proposal should declare a NEW CAPABILITY or extend an existing capability's paths (PATHS <capability>: add [...])"
  else
    warn "$count changed file(s) are covered by no behavior file: ${list}— consider /behaviors capture for this area"
  fi
fi

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
if [ "$ERRORS" -gt 0 ]; then
  echo "behavior-check: FAIL — $ERRORS error(s), $WARNINGS warning(s) (base $(git rev-parse --short "$BASE"))"
  exit 1
fi
info "pass — $WARNINGS warning(s) (base $(git rev-parse --short "$BASE"))"
exit 0
