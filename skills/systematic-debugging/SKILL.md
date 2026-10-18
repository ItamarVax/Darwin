---
name: systematic-debugging
description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes. Four-phase root cause process that prevents guess-and-fix loops.
---

# Systematic Debugging

## Overview

Random fixes waste time and create new bugs. Quick patches mask underlying issues.

**Core principle:** ALWAYS find root cause before attempting fixes. Symptom fixes are failure.

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## When to Use

Use for ANY technical issue:
- Test failures
- Bugs in production
- Unexpected behavior
- Performance problems
- Build failures
- Integration issues

**Use this ESPECIALLY when:**
- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- You've already tried multiple fixes
- Previous fix didn't work

## Constraints

- **No test command** (`commands.test` absent from `.darwin/config.json`): before Phase 4, STOP and offer onboarding's test setup (`onboarding` skill, `references/test-setup.md`)
  - Accepted → set it up, then continue with the regression test
  - Declined → fix without a regression test and say so explicitly: "Fixed without a regression test — no test setup."
- **Never push.** Suggest `/git-ship` when the user wants push + PR.

## The Four Phases

Complete each phase before proceeding to the next.

### Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

1. **Read Error Messages Carefully**
   - Don't skip past errors or warnings
   - Read stack traces completely
   - Note line numbers, file paths, error codes

2. **Reproduce Consistently**
   - Can you trigger it reliably?
   - What are the exact steps?
   - If not reproducible → gather more data, don't guess

3. **Check Recent Changes**
   - What changed that could cause this?
   - Git diff, recent commits
   - New dependencies, config changes

4. **Gather Evidence in Multi-Component Systems**

   When the system has multiple components:
   - Log what data enters each component boundary
   - Log what data exits each component boundary
   - Verify environment/config propagation
   - Run once to gather evidence showing WHERE it breaks
   - THEN investigate that specific component

5. **Trace Data Flow**

   When the error is deep in the call stack, use backward tracing.
   See `root-cause-tracing.md` in this directory for the complete technique.

### Phase 2: Pattern Analysis

1. **Find Working Examples** — locate similar working code in the same codebase
2. **Compare Against References** — if implementing a pattern, read the reference completely
3. **Identify Differences** — list every difference between working and broken, however small
4. **Understand Dependencies** — what other components, settings, or config does this need?

### Phase 3: Hypothesis and Testing

1. **Form Single Hypothesis**
   - State clearly: "I think X is the root cause because Y"
   - Be specific, not vague

2. **Test Minimally**
   - Make the SMALLEST possible change to test the hypothesis
   - One variable at a time
   - Don't fix multiple things at once

3. **Verify Before Continuing**
   - Did it work? Yes → Phase 4
   - Didn't work? Form NEW hypothesis
   - DON'T add more fixes on top

### Phase 4: Implementation

Commands come from `.darwin/config.json` (see the `execute` skill's Darwin Config section). No `commands.test` → see Constraints above before starting.

1. **Write a Failing Regression Test First**
   - One test that reproduces the bug through the code path you traced in Phase 1
   - Run it with `commands.testScoped` (falls back to `commands.test`)
   - It MUST fail, and fail for the bug's reason — not an import error, a typo, or a missing fixture
   - Passes already? Your test doesn't capture the bug, or your root cause is wrong. Return to Phase 1.

2. **Implement Single Fix** — address the root cause, ONE change at a time, until the regression test passes

3. **Verify Fix** — run the full `commands.test`; confirm the issue is resolved and nothing else broke

4. **Keep Behaviors True** (when `.darwin/behaviors/` exists and `behaviors.enabled` is not `false` — formats in the `behaviors` skill's `references/formats.md`):
   - Bug contradicts an `intended` requirement → the code was wrong. Point that requirement's `Tests:` at the new regression test (add the pointer; keep existing ones that still apply).
   - The behavior file itself is wrong → edit it in the same commit (keep IDs; a new requirement takes the next number).
   - Covered code changed but behavior did not (e.g. the bug was never described) → add the trailer `Behavior-Change: none (<capability>) — <reason>`, one per capability.

5. **Drift Check, Then Commit**
   - Stage only the fix, the regression test, and any behavior file edit
   - Write the commit message to a temp file, run the drift check with it, then commit from that file:

     ```bash
     msg=$(mktemp)
     # write the commit message to "$msg"
     # Commit only if the drift check passes — never chain these with ";".
     DARWIN_COMMIT_MSG_FILE="$msg" "<plugin-root>/scripts/behavior-check.sh" --staged && git commit -F "$msg"
     ```

   - Resolve `<plugin-root>` per the `behaviors` skill's "Running the drift check". Exit `1` → fix what it reports, or ask the user. Never commit past an error. Never push.

6. **If Fix Doesn't Work** (after 3 attempts):
   - STOP and question the architecture
   - Each fix revealing new problems in different places = architectural problem
   - Discuss with the user before attempting more fixes

7. **If Fix Grows Past Quick Size** — more than a few files, a design decision, or a change to a shared contract:
   - STOP. Leave the regression test and your root-cause findings uncommitted, summarize them
   - Hand off to the feature track (`/plan`) — the root cause becomes its research input

## Red Flags — STOP and Return to Phase 1

If you catch yourself thinking:
- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Add multiple changes, run tests"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "One more fix attempt" (when already tried 2+)
- Proposing solutions before tracing data flow

**ALL of these mean: STOP. Return to Phase 1.**

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast for simple bugs. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "Just try this first, then investigate" | First fix sets the pattern. Do it right from the start. |
| "I see the problem, let me fix it" | Seeing symptoms ≠ understanding root cause. |
| "One more fix attempt" (after 2+ failures) | 3+ failures = architectural problem. Question the pattern. |

## Quick Reference

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| 1. Root Cause | Read errors, reproduce, check changes, gather evidence | Understand WHAT and WHY |
| 2. Pattern | Find working examples, compare | Identify differences |
| 3. Hypothesis | Form theory, test minimally | Confirmed or new hypothesis |
| 4. Implementation | Failing regression test, fix root cause, full suite, drift check | Test red then green, bug resolved, nothing else broke |

## Supporting Techniques

Available in this directory:
- **`root-cause-tracing.md`** — trace bugs backward through call stack to find the original trigger
- **`defense-in-depth.md`** — add validation at multiple layers after finding root cause

## Capturing Lessons

When something went wrong during this change — a test that kept failing, an escalation, a correction from the user, a wrong first guess at the cause — end with the `compound` skill's **Light Capture Mode**: one question ("worth remembering?"), or, when the mistake matches an existing lesson in `.darwin/learnings/`, a `recurrence` event for that lesson instead of a new one. Nothing went wrong → skip it.

## Integration

- **When to invoke**: Any bug, test failure, or unexpected behavior
- **Pairs with**: EXECUTE mode (when executor hits unexpected issues), REVIEW mode (when reviewer finds behavioral bugs)
- **Does NOT replace**: `reviewing-implementation` skill (that's for plan compliance, not debugging)
- **Track**: this is the bugfix track (see `quick`'s Track Choice); escalates to `plan` when the fix grows past quick size
- **Related**: `behaviors` (formats, `behavior-check.sh`), `onboarding` (test setup), `execute` (Darwin Config: `commands.*`)
