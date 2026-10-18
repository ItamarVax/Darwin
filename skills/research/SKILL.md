---
name: research
description: >
  Gather information about the codebase, dependencies, and requirements.
  Use when the user asks to understand, explore, or investigate something
  before making changes.
---

# Research

> Begin every reply with `[MODE: RESEARCH]`. See `using-darwin` for the full contract.

Information gathering and understanding existing code, systems, and requirements.

**Core principle**: understand fully before acting. Dispatch a subagent for the heavy reading; steer it via post-return refinement.

## When This Skill Fires

- User says `/research`, "let's research", "help me understand", or similar
- User starts from a ticket: `/research PROJ-123` or `/research <jira-url>/browse/PROJ-123` (see Ticket Entry Point)
- Beginning of a new feature or bugfix where understanding is needed
- Encountering unfamiliar code or systems
- Before making any significant changes to existing code

## Constraints

- **Allowed**: Dispatching `darwin-researcher`, reading the produced report, presenting findings to the user, asking clarifying questions in the main session, querying MCP tools when the user wants to bypass the subagent for a quick lookup, reading up to ~3 files directly for a small lookup (a config value, one function, a behavior file)
- **Forbidden**: Doing the real reading in the main session — anything past a few files goes through `darwin-researcher` (that's the cost-control mechanism), making code changes, suggesting implementations

## How Research Works

Research is split across two contexts:

1. **Main session** (Opus on Claude Code, default on Cursor) — handles the conversation with the user: clarifying ambiguous topics before dispatch, presenting the subagent's findings, running the refinement loop, handing off to innovate.
2. **`darwin-researcher` subagent** (Sonnet on Claude Code) — does the file reading and synthesis in isolated context. Writes the full findings to `.cursor/darwin-research.md` (this is its primary deliverable, not a side effect). Returns a **short pointer summary** to the orchestrator — file location, the Summary bullets verbatim, a per-section coverage line, Open questions, and a files-read count. The orchestrator reads the full report from the file when it needs to.

This split is the cost-control lever. The subagent reads at ~1/5 the price; the main session stays lean for the conversational layer.

## Model Selection

The orchestrator dispatches `darwin-researcher` with a per-call `model` parameter. The mapping mirrors the `execute` and `reviewing-implementation` skills:

| Host | `model` parameter |
|------|-------------------|
| Claude Code | `model: "sonnet"` |
| Cursor | omit `model` (use host default) |

Apply this to every dispatch (initial research and refinements).

## Ticket Entry Point

Work can start from a Jira ticket. This section is the single definition of how Darwin handles one; `plan` and `quick` reuse it.

**Detection — explicit only.** Look for a ticket reference only in the arguments of an explicit `/research`, `/plan`, or `/quick` invocation: an Atlassian URL containing `/browse/KEY-123`, or a bare key matching `[A-Z][A-Z0-9]+-[0-9]+`. Never infer a ticket from general conversation, and never from hooks.

**Fetch — in the main session, before dispatch.** Use the Atlassian MCP's Jira issue lookup to get: key, URL, issue type, status, summary, description, acceptance criteria (the dedicated field if the project has one, otherwise the matching section of the description), and linked issues (key + summary). One fetch is cheap, and doing it here lets the user confirm the ticket before research starts:

```
PROJ-123 (Story, In Progress): <summary> — researching this ticket.
```

**Failures:**
- **Not found** — the key may just be text that looks like one (e.g. `CVE-2024`). Say so and treat it as part of the topic.
- **MCP not connected or not authorized** — say so, ask the user to paste the ticket text (or continue without it), and still record the key.

**Carry it forward.** The ticket travels as a `Ticket:` block in the researcher's prompt → `## Ticket` in `.cursor/darwin-research.md` → the `Ticket` field in the plan's Overview (the durable record) → the branch name, a `Refs: KEY` trailer on every commit, and the merge request title. Darwin never writes back to Jira (comments, transitions) on its own.

## Dispatch Flow

```
User: /research <topic>
  ↓
1. Pre-dispatch clarification (optional)
2. Initial dispatch → darwin-researcher
3. Present verbose return + adaptive recommendation
4. User picks (a)/(b)/(c)/(d)/(e)
5. On (a/b/c) → refinement dispatch → back to step 3
   On (d)    → invoke innovate
   On (e)    → invoke plan
```

### Step 1: Pre-dispatch clarification (optional)

Skip this step by default. Only ask a clarifying question if the topic is
**genuinely ambiguous** — the kind of ambiguity that would send the subagent
exploring the wrong subsystem entirely.

A topic is genuinely ambiguous when:
- It references a feature name that maps to multiple subsystems
- The user provided no scope hints and the codebase has multiple plausible
  interpretations

Most topics are not ambiguous. Trust the subagent's `## Open questions`
mechanism to flag interpretive forks — that's cheaper than asking up front.

### Step 2: Initial dispatch

The research file is a transient, per-session artifact — make sure it is never committed. If it isn't already ignored, add it to the clone-local exclude file (this touches no tracked file):

```bash
git check-ignore -q .cursor/darwin-research.md || \
  echo ".cursor/darwin-research.md" >> "$(git rev-parse --path-format=absolute --git-common-dir)/info/exclude"
```

Use the `Task` tool to dispatch the researcher:

```
Task tool call:
  subagent_type: "darwin-researcher"
  model: <see Model Selection above>
  prompt: <see template below>
```

**Prompt template** (initial call, no refinement flag):

```
Research topic: <verbatim user request; for a ticket-only request, the ticket summary and description>
Scope hints: <files/dirs the user mentioned, or "none">
Out-of-scope: <anything excluded, or "none">
Ticket: <key, URL, type, status, summary, acceptance criteria verbatim, linked issues — or "none">
```

### Step 3: Present return + adaptive recommendation

The subagent returns a short pointer summary (file location, Summary bullets
verbatim, a `## Sections written` coverage line, Open questions, files-read
count). Surface the Summary and Open questions to the user. If the user
needs more detail than the Summary provides, read `.cursor/darwin-research.md`
directly — that is where the full findings, signatures, data flow,
integration points, behaviors, and test setup & coverage live. Then add an **adaptive
recommendation** based on the return's content:

- **Clean findings** (Open questions empty AND Dead ends empty or trivial)
  → recommend `(d) move to innovate` — or `(e) go straight to plan` when
  the findings leave one obvious approach (see Next Step)
- **Open questions present OR dead ends suggest gaps**
  → recommend the specific menu option that addresses the gap:
  - Open question about a subtopic the subagent identified → `(a) dig deeper on X`
  - Dead ends in an area the user cares about → `(b) broaden to include Y`
  - Misinterpretation flagged → `(c) revise focus on Z`

Present the menu:

```
Findings written to .cursor/darwin-research.md. What next?

(a) Dig deeper on a specific area
(b) Broaden to something I missed
(c) Revise — I focused too narrowly on the wrong thing
(d) Move on to innovate
(e) Go straight to plan — one obvious approach

Recommend: <(a/b/c/d/e) with one-line reason based on the return>
```

The recommendation is a hint, not a decision. The user always picks.

### Step 4: Refinement dispatch (on a/b/c)

Re-dispatch `darwin-researcher` with the refinement flag set and a focused
sub-topic. The subagent will read `.cursor/darwin-research.md` first, then
extend or revise.

**Prompt template** (refinement call):

```
Research topic: <refined sub-topic from the user's response>
Scope hints: <updated hints, or "none">
Out-of-scope: <updated exclusions, or "none">
Refinement: yes — extend or revise .cursor/darwin-research.md per the topic above.
```

Loop back to Step 3 with the new return.

### Refinement soft cap

After **3 refinements** in a single research session, add to the menu
presentation:

```
(Note: we've refined 3 times. Consider moving to innovate to avoid scope creep —
the research file already captures the core findings.)
```

This is a nudge, not a hard cap. The user can keep refining if they need to.

### Step 5: Hand off to innovate (on d)

Invoke the innovate skill. Innovate will read `.cursor/darwin-research.md`
automatically as its handoff context.

```
Research complete. Findings in .cursor/darwin-research.md. Invoking innovate...
```

On (e), invoke the plan skill instead (see Next Step).

## External Research via MCP

When MCP servers are configured (see `mcp.json`), the `darwin-researcher`
subagent has access to external tools:

### DeepWiki

- **`read_wiki_structure`** — Repository architecture/modules overview
- **`read_wiki_contents`** — Detailed documentation for a topic
- **`ask_wiki_question`** — Targeted synthesized answer about a repository

### Atlassian (Jira + Confluence)

- **Search Jira issues** — Tickets by key, summary, or JQL (the ticket named in `/research <TICKET>` is fetched by the main session — see Ticket Entry Point)
- **Read Confluence pages** — Requirements docs, ADRs, runbooks
- **Cross-reference** — Linked Jira tickets and Confluence pages

### When to use external tools

Prefer local codebase analysis first. The subagent is instructed to reach
for external tools only when:
- The codebase uses a library/framework whose internals matter
- The task references Jira tickets or Confluence pages
- Local documentation is sparse or contradicts the code

External-tool findings appear inline in the report's `## Findings` section
alongside local findings.

## Next Step

After the user picks `(d) move on`, auto-invoke the innovate skill:

```
Research complete. Findings in .cursor/darwin-research.md. Invoking innovate...
```

If the findings leave **one obvious approach** — no real design choice to
make — skip innovate. On `(e)`, or when the user asks to go straight to
planning, invoke the plan skill instead; plan writes the change proposal
(`.darwin/proposal.md`) that innovate would otherwise have written:

```
Research complete. Findings in .cursor/darwin-research.md. One obvious approach — skipping innovate. Invoking plan...
```

## Integration

- **Chains to**: `innovate` skill (default), `plan` skill (one obvious approach — plan writes the proposal)
- **Dispatches**: `darwin-researcher` agent
- **Produces**: `.cursor/darwin-research.md` (including `## Ticket` and `## Draft behavior changes` when started from a ticket)
- **References**: `project-context.mdc` for domain-specific research areas, `behaviors` skill (behavior files are read before code; ticket acceptance criteria become draft behavior changes), `.darwin/config.json` (`commands.test`)
- **MCP tools**: DeepWiki, Atlassian (when configured) — inherited by the subagent
