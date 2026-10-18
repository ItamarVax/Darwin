#!/usr/bin/env bash
# Regression checks for Darwin's scripts (behavior-check.sh, archive-change.sh).
# Builds throwaway git repos in a temp dir and checks exit codes and output.
# Run after any change under scripts/:  bash scripts/test-scripts.sh
# Requires: bash, git, jq.

set -uo pipefail

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
CHECK="$SCRIPTS/behavior-check.sh"
ARCHIVE="$SCRIPTS/archive-change.sh"
FORMATS="$SCRIPTS/../skills/behaviors/references/formats.md"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# new_repo <name> → creates a repo with a main branch holding an export
# capability (behavior file + code + test) and checks out a feature branch.
new_repo() {
  local dir="$TMP/$1"
  mkdir -p "$dir" && cd "$dir" || exit 1
  git init -q -b main
  mkdir -p src/export tests .darwin/behaviors
  printf 'def export(rows):\n    return rows\n' > src/export/csv.py
  printf 'def test_empty_export():\n    assert True\n' > tests/test_csv.py
  cat > .darwin/behaviors/export.md <<'EOF'
---
capability: export
paths: [src/export/]
---
# Export
Purpose: users download scan results as CSV.

### EXPORT-1: Empty results
Status: intended
WHEN a user exports a scan with no findings
THEN the file contains only the header row
Tests: tests/test_csv.py::test_empty_export
EOF
  git add -A && git commit -q -m "init"
  git checkout -q -b feat/x
}

# run_check [args...] → sets OUT, RC
run_check() {
  OUT=$(bash "$CHECK" "$@" 2>&1)
  RC=$?
}

expect_rc() {
  local want="$1" label="$2"
  if [[ "$RC" -eq "$want" ]]; then ok; else fail "$label: expected exit $want, got $RC"; echo "$OUT" | sed 's/^/    /'; fi
}

# --- behavior-check.sh -----------------------------------------------------

# 1. Covered change, no behavior update → fail
new_repo c1
echo "# change" >> src/export/csv.py
git commit -qam "feat(export): tweak"
run_check; expect_rc 1 "covered change without behavior update"
[[ "$OUT" == *"capability 'export'"* ]] && ok || fail "covered change: message should name the capability"

# 2. Covered change + Behavior-Change trailer → pass
new_repo c2
echo "# change" >> src/export/csv.py
git commit -qam "refactor(export): tidy

Behavior-Change: none (export) — internal tidy, same output"
run_check; expect_rc 0 "covered change with Behavior-Change trailer"

# 3. Covered change + behavior file updated → pass
new_repo c3
echo "# change" >> src/export/csv.py
printf '\n### EXPORT-2: Header\nStatus: intended\nWHEN any export runs\nTHEN the first row is the header\nTests: tests/test_csv.py::test_empty_export\n' >> .darwin/behaviors/export.md
git commit -qam "feat(export): header"
run_check; expect_rc 0 "covered change with behavior file updated"

# 4. Tests: pointer to a missing test → fail
new_repo c4
sed -i.bak 's/::test_empty_export/::test_does_not_exist/' .darwin/behaviors/export.md && rm .darwin/behaviors/export.md.bak
git commit -qam "docs: break pointer"
run_check; expect_rc 1 "test pointer to a missing test"
[[ "$OUT" == *"test_does_not_exist"* ]] && ok || fail "missing test: message should name the test"

# 5. Duplicate ID across two files → fail
new_repo c5
cat > .darwin/behaviors/import.md <<'EOF'
---
capability: import
paths: [src/import/]
---
# Import
Purpose: users upload data.

### EXPORT-1: Wrong prefix and duplicate
Status: observed
WHEN x
THEN y
Tests: none yet
EOF
git add -A && git commit -qm "docs: duplicate"
run_check; expect_rc 1 "duplicate ID across files"
[[ "$OUT" == *"used more than once"* ]] && ok || fail "duplicate ID: message should say used more than once"

# 6. Reused tombstone ID → fail
new_repo c6
cat >> .darwin/behaviors/export.md <<'EOF'

### EXPORT-2: Excel output
Status: removed
Reason: dropped

### EXPORT-2: Reuse of a removed ID
Status: observed
WHEN x
THEN y
Tests: none yet
EOF
git commit -qam "docs: reuse tombstone"
run_check; expect_rc 1 "reused tombstone ID"

# 7. Uncovered change, no proposal → pass with WARN
new_repo c7
mkdir -p src/other && echo "x = 1" > src/other/mod.py
git add -A && git commit -qm "feat(other): add"
OUT=$(LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bash "$CHECK" 2>&1); RC=$?; expect_rc 0 "uncovered change without proposal (UTF-8 locale)"
[[ "$OUT" == *"WARN"*"src/other/mod.py"* ]] && ok || fail "uncovered change: expected a WARN naming the file"

# 8. Uncovered change on a branch with a proposal → fail
new_repo c8
printf '# Change: x\n' > .darwin/proposal.md
mkdir -p src/other && echo "x = 1" > src/other/mod.py
git add -A && git commit -qm "feat(other): add with proposal"
run_check; expect_rc 1 "uncovered change on a proposal branch"

# 9. strictUncovered: true → fail without a proposal
new_repo c9
echo '{"behaviors":{"strictUncovered":true}}' > .darwin/config.json
mkdir -p src/other && echo "x = 1" > src/other/mod.py
git add -A && git commit -qm "feat(other): strict"
run_check; expect_rc 1 "strictUncovered"

# 10. No .darwin/behaviors/ → no-op pass
mkdir -p "$TMP/c10" && cd "$TMP/c10" && git init -q -b main
echo a > a.py && git add -A && git commit -qm init && git checkout -q -b feat/x
echo b >> a.py && git commit -qam change
run_check; expect_rc 0 "no behaviors directory"
[[ "$OUT" == *"nothing to check"* ]] && ok || fail "no behaviors dir: expected 'nothing to check'"

# 11. behaviors.enabled: false → no-op pass
new_repo c11
echo '{"behaviors":{"enabled":false}}' > .darwin/config.json
echo "# change" >> src/export/csv.py
git add -A && git commit -qm "feat(export): disabled"
run_check; expect_rc 0 "behaviors disabled"

# 12. Test files and docs are ignored (no uncovered warning)
new_repo c12
mkdir -p pkg/tests && echo "def test_a(): pass" > pkg/tests/test_a.py && echo "# doc" > NOTES.md
git add -A && git commit -qm "test: add"
run_check; expect_rc 0 "ignored test and doc files"
[[ "$OUT" != *"WARN"* ]] && ok || fail "ignored files: expected no WARN"; [[ "$OUT" != *"WARN"* ]] || echo "$OUT" | sed 's/^/    /'

# 13. --staged with a pending trailer message → pass
new_repo c13
echo "# change" >> src/export/csv.py && git add src/export/csv.py
printf 'refactor(export): x\n\nBehavior-Change: none (export) — same output\n' > "$TMP/msg13"
OUT=$(DARWIN_COMMIT_MSG_FILE="$TMP/msg13" bash "$CHECK" --staged 2>&1); RC=$?
expect_rc 0 "--staged with pending trailer"

# 14. --staged without a trailer → fail
new_repo c14
echo "# change" >> src/export/csv.py && git add src/export/csv.py
run_check --staged; expect_rc 1 "--staged without trailer"

# 15. Intended requirement without a test pointer → fail
new_repo c15
printf '\n### EXPORT-2: No tests\nStatus: intended\nWHEN x\nTHEN y\nTests: none yet\n' >> .darwin/behaviors/export.md
git commit -qam "docs: intended without tests"
run_check; expect_rc 1 "intended without test pointer"

# 16. The example behavior file in formats.md passes integrity
new_repo c16
awk '/^```markdown$/ && !done {grab=1; next} grab && /^```$/ {exit} grab {print}' "$FORMATS" > .darwin/behaviors/export.md
mkdir -p tests/export && printf 'def test_empty_export():\n    pass\n' > tests/export/test_csv.py
git add -A && git commit -qm "docs: formats example"
run_check; expect_rc 0 "formats.md example behavior file"

# 17. Usage error → exit 2
new_repo c17
run_check --bogus; expect_rc 2 "unknown flag"

# 17b. pytest class node and a comma inside a test title both resolve
new_repo c18
mkdir -p tests && printf 'class TestCsv:\n    def test_header(self):\n        pass\n' > tests/test_cls.py
printf "it('exports a, b and c', () => {})\n" > tests/export.test.js
printf '\n### EXPORT-2: Header\nStatus: intended\nWHEN any export runs\nTHEN the first row is the header\nTests: tests/test_cls.py::TestCsv::test_header, tests/export.test.js::exports a, b and c\n' >> .darwin/behaviors/export.md
git add -A && git commit -qm "docs: class node and comma title"
run_check; expect_rc 0 "pytest class node and comma-containing title"

# 17c. Local main ahead of a stale origin/HEAD: the newer base wins
mkdir -p "$TMP/origin19" && cd "$TMP/origin19" && git init -q -b main && echo a > a.py && git add -A && git commit -qm init
git clone -q "$TMP/origin19" "$TMP/c19" && cd "$TMP/c19"
mkdir -p .darwin/behaviors src && echo x > src/f.py && printf 'def test_x(): pass\n' > test_x.py
printf -- '---\ncapability: core\npaths: [src/]\n---\n# Core\nPurpose: p.\n\n### CORE-1: x\nStatus: observed\nWHEN x\nTHEN y\nTests: test_x.py::test_x\n' > .darwin/behaviors/core.md
git add -A && git commit -qm "docs: behaviors on local main (unpushed)"
git checkout -q -b fix/x && echo y >> src/f.py && git commit -qam "fix: change covered code"
run_check; expect_rc 1 "stale origin/HEAD does not hide a covered change"

# --- archive-change.sh -------------------------------------------------------

# 18. Archives the plan and proposal into .darwin/archive/<slug>/
new_repo a1
printf '# Plan\n' > .darwin/darwin-progress.md && printf '# Change: x\n' > .darwin/proposal.md
OUT=$(bash "$ARCHIVE" 2>&1); RC=$?
expect_rc 0 "archive-change moves files"
[[ -f .darwin/archive/x/plan.md && -f .darwin/archive/x/proposal.md && ! -e .darwin/darwin-progress.md ]] && ok || fail "archive-change: files not in .darwin/archive/x/"

# 19. Refuses to overwrite an existing archive
printf '# Plan again\n' > .darwin/darwin-progress.md
OUT=$(bash "$ARCHIVE" 2>&1); RC=$?
expect_rc 4 "archive-change refuses existing target"
[[ -f .darwin/darwin-progress.md ]] && ok || fail "archive-change: progress file moved despite refusal"

echo "PASS: $PASS  FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]]
