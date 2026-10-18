# Gates: Red Check, Test Lock, Wave Gate, Post-Wave Suite, Behavior Deltas

The mechanical checks the execute orchestrator runs. They replace per-task AI
review: "done" is decided by commands, with their output recorded in the
Execution Log. All commands come from `.darwin/config.json` (the `execute`
skill's Darwin Config section). Run every command from the worktree root.

Status values are the plan skill's Status Vocabulary
(`skills/plan/references/progress-file.md`); use no others.

---

## 1. Red check (after Task 0, standard mode)

Task 0 wrote the skeleton and every test change. Before any other task runs,
prove the tests are real:

1. Run `commands.testScoped` over every test file Task 0 added or changed (fallback `commands.test`).
2. **Every new and changed test must be collected and run.** A collection, import, or syntax error fails the red check → re-dispatch Task 0 (fresh executor, High) with the error output. Do not continue to wave 1.
3. Check each test's outcome against its delta type:

| Test for | Expected | If it passes instead |
|----------|----------|----------------------|
| `ADDED` behavior | Fails — "not implemented" or an assertion | Flag to the user: a test that passes before the change proves nothing. Ask whether to strengthen it (re-dispatch Task 0) or accept it |
| `MODIFIED` behavior | Fails on an assertion (the old code still does the old thing) | Same as above |

4. Record the red-check result in the Execution Log under `### Wave 0 — Red check`: the command, its exit code, and a per-test line (`test id — fails as expected | passes (flagged) | error`).

## 2. Test lock (after the red check)

Lock every **test-support file** so executors cannot change what "done" means:

- every file Task 0 wrote or changed
- every file under the project's test directories (fixtures, `conftest.py`, snapshots, helpers)
- the test-runner configs (e.g. `pytest.ini`, `setup.cfg`, `jest.config.*`, `vitest.config.*`, and `pyproject.toml` / `package.json` as whole files when they hold test configuration)

Record each file and its hash in the progress file's `## Test lock` table:

```bash
for f in <test-support files>; do
  printf '| %s | %s |\n' "$f" "$(git hash-object "$f")"
done
```

Also write the `## Expected red` section: the locked test IDs that belong to
tasks not yet `COMPLETE` (in practice, every test Task 0 added or changed).

Commit Task 0 (skeleton, tests, and the progress file) as
`test({scope}): Task 0 — skeleton and tests for <change>` and set it `COMPLETE`.

**Re-locking.** When the user resolves a `BLOCKED: test defect` by changing a
test or a behavior, the orchestrator makes that change, re-runs the red check
for the affected tests, updates their rows in `## Test lock`, and commits it as
`test({scope}): adjust <test> — <reason>`.

## 3. Wave gate (after every wave returns)

Run once all tasks dispatched in the wave have reported (or the inline task is
finished). For each task whose report is `DONE` or `DONE_WITH_CONCERNS`:

1. **Re-run its tests** with `commands.testScoped` over the task's test files (reduced/legacy mode: its `Acceptance` commands). Do not trust the report's verification block — run them yourself.
2. **Verify the test lock**: re-hash every file in `## Test lock`; any mismatch → reject the result of the task whose files or report touched it, and restore the file (`git checkout -- <file>`).
3. **Check the working tree**: `git status --porcelain` may list only the wave's combined `Files` plus newly added test files. Anything else → find the owning task and reject its result; never commit stray files.

Then:

- **All green** → stage only that task's reported files (plus `.darwin/darwin-progress.md`), commit `{type}({scope}): Task {N} — {task title}` (with `Refs: KEY-123` when the plan's Overview has a `Ticket`), set the task `COMPLETE`, and remove its tests from `## Expected red`.
- **Red** → handle per section 4.

Record each task's gate result in the Execution Log under its entry:
`Gate: pass` or `Gate: red — <command> exit <code>`.

## 4. Red handling and escalation

Follow the escalation table in [model-selection.md](model-selection.md):

1. **First red gate** → re-dispatch the task to a **fresh** executor, same tier, with the failing command and its output.
2. **Second red gate** → Fast tasks go to High with both failure outputs; High tasks go to the user.
3. **`BLOCKED: test defect`** → show the user the executor's reasoning and ask: fix the code (re-dispatch), fix the test (re-lock, section 2), or change the behavior (update the proposal, then re-lock).
4. **`DONE_WITH_CONCERNS`** with green tests → read the concerns; proceed through the gate, or re-dispatch if a concern is a real defect the tests miss (and note that gap for the checker).

Never edit a locked test yourself to make a gate pass.

## 5. Post-wave suite (after every wave from wave 1)

After the wave's commits, run the full `commands.test` (skip this section when the project has no `commands.test`). Exclude:

- tests listed as failing in the Overview's `Baseline`
- tests still in `## Expected red`

A new failure means tasks that pass on their own break each other. Create a
fix task owned by the latest task that touched the failing area, dispatch it to
a fresh executor with that task's context and the failure output, and gate it
like any other task. Record the suite result in the Execution Log under
`### Wave [N] — Suite`.

## 6. Applying behavior deltas (after the last wave, standard and reduced modes)

The orchestrator is the only writer of `.darwin/behaviors/`. Apply the
proposal's `## Behavior changes` exactly as the `behaviors` skill's
`references/formats.md` ("Applying the deltas") describes:

- `ADDED` / `MODIFIED` → write the requirement block with `Status: intended` and `Tests:` pointers to the tests that now cover it (in reduced mode, `observed` with `Tests: none yet`)
- `REMOVED` → tombstone
- `NEW CAPABILITY` / `PATHS` → create the file / extend `paths`

Then run the drift check — `behavior-check.sh` (see the `execute` skill's
"Running scripts") — and fix what it reports:

- **Errors in behavior files** (integrity, pointers) → fix the behavior files.
- **A capability whose covered code changed but that the proposal does not touch** (e.g. a refactor inside the feature) → confirm from the diff and the tests that its behavior did not change, then record it with an empty commit carrying the trailer: `git commit --allow-empty -m "chore(behaviors): no behavior change in <cap>" -m "Behavior-Change: none (<cap>) — <reason>"`. If its behavior *did* change, stop and ask the user to extend the proposal.

Commit `docs(behaviors): apply <change> deltas`, then write
`### Behavior deltas — applied` in the Execution Log and commit the progress
file. Execute and resume use that heading to know this step is done — never
apply the deltas twice.

Legacy mode skips this section (no proposal). If behavior files exist in a
legacy project, finishing's drift check may still report covered capabilities;
handle them with the trailer commit above.
