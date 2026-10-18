---
name: create-skill
description: >
  Guide users through creating effective Cursor skills with proper structure,
  descriptions, and Darwin integration. Use when creating, writing, or
  authoring a new skill, or when asking about SKILL.md format or best practices.
---

# Creating Skills

Guide for authoring Cursor skills — markdown files that teach the agent how to
perform specific tasks.

## Before You Begin

Gather requirements before writing. Infer from conversation context when
possible. Otherwise ask using the structured question tool (`AskQuestion` on Cursor, `AskUserQuestion` on Claude Code) (fall back to conversational):

1. **Purpose and scope** — what task or workflow the skill helps with
2. **Target location** — project (`.cursor/skills/`) vs personal (`~/.cursor/skills/`)
3. **Trigger scenarios** — when the agent should auto-apply this skill
4. **Key domain knowledge** — what the agent wouldn't already know
5. **Output format** — templates, styles, or formats required
6. **Existing patterns** — conventions or examples to follow

## Storage Locations

| Type | Path | Scope |
|------|------|-------|
| Project | `.cursor/skills/skill-name/` | Shared via VCS |
| Personal | `~/.cursor/skills/skill-name/` | All your projects |

Never create skills in `~/.cursor/skills-cursor/` — reserved for Cursor
built-in skills.

## Directory Layout

Skills are directories with a required `SKILL.md` and optional supporting files:

```
# Self-contained
skill-name/
  SKILL.md

# With reusable tool
skill-name/
  SKILL.md
  helper-script.sh

# With heavy reference
skill-name/
  SKILL.md
  api-reference.md
  scripts/
    tool.py
```

Keep file references one level deep — link directly from SKILL.md to reference
files. Deeply nested references may result in partial reads.

## SKILL.md Structure

Every skill needs YAML frontmatter and a markdown body:

```yaml
---
name: skill-name
description: Use when [specific triggering conditions]
---
```

### Required Frontmatter

| Field | Constraints | Purpose |
|-------|-------------|---------|
| `name` | Max 64 chars, lowercase letters/numbers/hyphens | Unique identifier |
| `description` | Max 1024 chars, non-empty | Discovery — agent decides when to apply |

### Body Template

```
# Skill Name

## Overview
Core principle in 1-2 sentences.

## When to Use
Bullet list with symptoms and use cases. When NOT to use.

## [Core Content]
The skill's main guidance — patterns, workflows, reference.

## Common Mistakes
What goes wrong and how to fix it.
```

## Writing Effective Descriptions

The description is critical for discovery. The agent reads it to decide whether
to load the full skill.

### Rules

- Write in third person (injected into system prompt)
- Start with "Use when..." to focus on triggering conditions
- Include specific trigger terms and symptoms
- Include both WHAT (capabilities) and WHEN (trigger scenarios)
- **Never summarize the skill's workflow in the description**

### Why No Workflow Summaries

When a description summarizes the skill's workflow, agents may follow the
description instead of reading the full skill content. A description saying
"code review between tasks" caused agents to do one review, even though the
skill body specified two. When changed to just triggering conditions, agents
read the full skill and followed it correctly.

```yaml
# BAD: Summarizes workflow — agent shortcuts past the skill body
description: Use when executing plans — dispatches subagent per task with review

# BAD: Process detail leaks into description
description: Use for TDD — write test first, watch it fail, write minimal code

# GOOD: Just triggering conditions
description: Use when executing implementation plans with independent tasks

# GOOD: Symptoms and contexts only
description: Use when tests have race conditions, timing dependencies, or pass/fail inconsistently
```

### Keyword Coverage

Use terms agents would search for:

- Error messages: "Hook timed out", "ENOTEMPTY", "race condition"
- Symptoms: "flaky", "hanging", "zombie", "pollution"
- Synonyms: "timeout/hang/freeze", "cleanup/teardown/afterEach"
- Tool names: actual commands, library names, file types

## Authoring Principles

### 1. Concise Is Key

The context window is shared with conversation history, other skills, and the
user's request. Every token competes for space.

The agent is already smart. Only add context it doesn't already have. Challenge
each paragraph: "Does this justify its token cost?"

### 2. Keep SKILL.md Under 500 Lines

For optimal performance. Use progressive disclosure — essential info in
SKILL.md, detailed reference in separate files.

### 3. Appropriate Degrees of Freedom

Match specificity to fragility:

| Freedom | When to Use | Example |
|---------|-------------|---------|
| **High** (text) | Multiple valid approaches, context-dependent | Code review guidelines |
| **Medium** (pseudocode) | Preferred pattern with variation OK | Report generation |
| **Low** (scripts) | Fragile operations, consistency critical | Database migrations |

## Common Patterns

### Template Pattern

Provide output format templates the agent fills in:

```
## Report structure

# [Analysis Title]

## Executive summary
[One-paragraph overview]

## Key findings
- Finding 1 with supporting data

## Recommendations
1. Specific actionable recommendation
```

### Examples Pattern

Show concrete input/output pairs:

```
## Commit message format

Input: Added user authentication with JWT tokens
Output:
feat(auth): implement JWT-based authentication
Add login endpoint and token validation middleware
```

### Workflow Pattern

Step-by-step checklists with clear steps:

```
## Processing workflow

- [ ] Step 1: Validate input
- [ ] Step 2: Transform data
- [ ] Step 3: Run validation
- [ ] Step 4: Write output
```

### Conditional Workflow

Guide through decision points:

```
**Creating new content?** → Follow "Creation workflow"
**Editing existing?** → Follow "Editing workflow"
```

### Feedback Loop

Validate after each step:

```
1. Make edits
2. Run: `python scripts/validate.py output/`
3. If validation fails → fix and re-run
4. Only proceed when validation passes
```

## Anti-Patterns

- **Vague names** — `helper`, `utils`, `tools` — use descriptive names like
  `processing-pdfs`, `analyzing-spreadsheets`
- **Verbose explanations** — explaining things the agent already knows
- **Too many options** — provide a clear default with an escape hatch
- **Time-sensitive info** — "If you're doing this before August 2025..." will
  become outdated; use a "deprecated patterns" section instead
- **Inconsistent terminology** — pick one term and use it throughout
- **Windows-style paths** — always use forward slashes

## Skill Creation Workflow

### Phase 1: Discovery

Gather: purpose, storage location, trigger scenarios, constraints, existing
patterns. Use the structured question tool (`AskQuestion` on Cursor, `AskUserQuestion` on Claude Code) for efficient structured gathering.

### Phase 2: Design

1. Draft skill name (lowercase, hyphens, max 64 chars)
2. Write specific, third-person description
3. Outline main sections needed
4. Identify if supporting files or scripts are needed

### Phase 3: Implementation

1. Create the directory under the chosen storage location
2. Write SKILL.md with frontmatter and body
3. Create supporting reference files if needed
4. Create utility scripts if needed

### Phase 4: Verification

Run the checklist below before considering the skill complete.

## Verification Checklist

- [ ] Description is specific, third-person, includes trigger terms
- [ ] Description does NOT summarize the skill's workflow
- [ ] SKILL.md body under 500 lines
- [ ] Consistent terminology throughout
- [ ] Examples are concrete, not abstract
- [ ] File references one level deep
- [ ] Progressive disclosure used for heavy content
- [ ] No time-sensitive information
- [ ] Skill can be discovered by an agent searching for relevant terms
