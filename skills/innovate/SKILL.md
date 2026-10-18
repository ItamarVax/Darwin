---
name: innovate
description: >
  Brainstorm and evaluate approaches for a task. Use when the user needs to
  explore design options, compare trade-offs, or generate creative solutions
  before planning.
---

# Innovate

> Begin every reply with `[MODE: INNOVATE]`. See `using-darwin` for the full contract.

Brainstorming potential approaches, exploring solutions, and creative problem-solving.

**Core principle**: explore before committing. Present options, validate incrementally, get approval.

## When This Skill Fires

- User says `/innovate`, "let's brainstorm", "what are our options", or similar
- After gathering information in research mode
- When exploring different approaches to a problem
- Before committing to a specific implementation approach

## Constraints

- **Allowed**: Proposing ideas, exploring options, comparing trade-offs, reading code for context, writing the change proposal `.darwin/proposal.md`
- **Forbidden**: Making code changes, writing detailed implementation specs, editing `.darwin/behaviors/*.md` (the proposal lists behavior changes; execute applies them)

## When to Skip Innovate

When research leaves **one obvious approach** — no real design choice, nothing to compare — skip innovate. Research hands straight to plan, and plan writes the change proposal instead. Don't invent alternatives just to fill step 3.

## Structured Brainstorming Process

### 1. Understand Context First

- **If `.cursor/darwin-research.md` exists, read it first.** This is the primary handoff from `/research` — its `## Summary`, `## Findings`, and `## Open questions` sections are the foundation for the design discussion. Reading it before asking the user clarifying questions avoids redundant exploration.
- Check the current project state (files, docs, recent commits)
- Before asking detailed questions, assess scope: if the request describes multiple independent subsystems, flag this immediately
- If the project is too large for a single design, help decompose into sub-projects first

> **Tip**: When you need code details beyond the research summary, prefer the `## Findings` and `## Key files` sections of `.cursor/darwin-research.md` before re-reading source files — the research subagent has already pulled the relevant excerpts, and re-reading the source pays the main-session model rate for content already captured cheaply.

### 2. Ask Questions One at a Time

- **One question per message** — don't overwhelm the user with 5 questions at once
- Prefer **multiple-choice questions** when possible (easier to answer than open-ended)
- Focus on understanding: purpose, constraints, success criteria
- If a topic needs more exploration, break it into multiple sequential questions

### 3. Propose Approaches with Recommendation

- Present **2–3 different approaches** with trade-offs
- **Lead with your recommended option** and explain why
- Include pros/cons for each option
- Be specific — "Option A uses X because Y" not "there are several approaches"

### 4. Present Design in Sections

- Once you believe you understand what to build, present the design
- **Scale each section to its complexity**: a few sentences if straightforward, more detail if nuanced
- **Ask after each section** whether it looks right so far
- Cover: architecture, components, data flow, error handling
- Be ready to go back and revise if something doesn't fit

### 5. Confirm Before Moving On

- After all sections are approved, summarize the complete design in one message
- **Write the change proposal** to `.darwin/proposal.md` in the main checkout (not a worktree — plan finalization moves it there). Follow the change-proposal format in the `behaviors` skill's `references/formats.md` exactly; don't restate it from memory:
  - `Why:`, `Approach:` (with the rejected approaches, one line each), `Out of scope:`, and `Test suite: present` when `.darwin/config.json` has `commands.test` (otherwise leave the `Test suite:` line out — plan offers test setup first and records `none (reduced mode)` only if the user declines)
  - `## Behavior changes` — start from research's `## Draft behavior changes` when there is one, and check IDs against the behavior files in research's `## Behaviors`
  - A `| Verify: <unit test | integration test | exercise app>` on **every** `ADDED` and `MODIFIED` line — how the change will be shown to work
  - When the area has no behavior file, a `NEW CAPABILITY <name>: paths [...] — <purpose>` line (with its requirements as `ADDED` lines); when new code lands under a path an existing capability should own, a `PATHS <capability>: add [...]` line instead
  - If `.darwin/proposal.md` already exists from another change, ask before overwriting it
- Show the user the written proposal and get **explicit approval of it**. That approval is the design approval — revise the file and ask again until the user approves it
- Get explicit approval before transitioning to plan

## Key Principles

- **One question at a time** — don't overwhelm with multiple questions
- **Multiple choice preferred** — easier to answer than open-ended when possible
- **YAGNI ruthlessly** — remove unnecessary features from all designs
- **Explore alternatives** — always propose 2–3 approaches before settling
- **Incremental validation** — present design in sections, get approval before moving on
- **Be flexible** — go back and clarify when something doesn't make sense
- **Section-appropriate depth** — a few sentences for obvious parts, detailed analysis for complex parts

## Project-Specific Innovation Areas

Refer to your project's `project-context.mdc` for domain-specific innovation areas.

## Typical Outputs

A structured innovate session produces:
- Confirmed understanding of the problem and constraints
- 2–3 evaluated approaches with a clear recommendation
- Section-by-section approved design covering architecture, components, and data flow
- `.darwin/proposal.md` — the change proposal, with a verification for every behavior change
- Explicit approval of the proposal, which is the approval to proceed to planning

## Next Step

After the proposal is approved, auto-invoke the plan skill, pointing it at the proposal:

```
Approaches explored and proposal approved (.darwin/proposal.md). Invoking plan with .darwin/proposal.md...
```

If more information is needed about specific options, invoke the research skill instead.

## Integration

- **Chains to**: `plan` skill (default), `research` skill (when more info needed)
- **Produces**: `.darwin/proposal.md` (the change proposal) in the main checkout
- **References**: `project-context.mdc` for domain context, `behaviors` skill (change-proposal format), `.cursor/darwin-research.md` (`## Behaviors`, `## Draft behavior changes`)
