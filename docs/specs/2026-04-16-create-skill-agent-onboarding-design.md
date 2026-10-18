# Create-Skill, Create-Agent & Onboarding Enhancement — Design Spec

## Goal

Add skill and agent authoring capabilities to the Vaxflow plugin, and extend
onboarding to generate project-specific skills and agents alongside rules.

## Deliverables

Three new/modified files in the plugin:

| File | Type | Purpose |
|------|------|---------|
| `skills/create-skill/SKILL.md` | New | Standalone skill-authoring guide |
| `skills/create-agent/SKILL.md` | New | Standalone agent-authoring guide |
| `skills/onboarding/SKILL.md` | Modified | Add skill/agent generation phases |

## Requirements Summary

- **Create-skill**: self-contained, combines Cursor's practical structure with
  superpowers' rigor (CSO, progressive disclosure). Vaxflow-aware.
- **Create-agent**: self-contained, covers subagent file format, system prompt
  writing, Vaxflow-specific agent patterns.
- **Onboarding**: after generating rules, propose project-specific workflow
  skills and agents based on discovery. Suggest-and-confirm UX — user approves
  before generation.
- Skills and agents are separate skills (not combined).

---

## 1. `create-skill` Skill

### Metadata

```yaml
name: create-skill
description: >
  Guide users through creating effective Cursor skills with proper structure,
  descriptions, and Vaxflow integration. Use when creating, writing, or
  authoring a new skill, or when asking about SKILL.md format or best practices.
```

### Sections (~300 lines total)

#### 1.1 Requirements Gathering

Infer from conversation context when possible. Otherwise ask using
`AskQuestion` tool (fall back to conversational):

1. **Purpose and scope** — what task or workflow the skill helps with
2. **Target location** — project (`.cursor/skills/`) vs personal (`~/.cursor/skills/`)
3. **Trigger scenarios** — when the agent should auto-apply this skill
4. **Key domain knowledge** — what the agent wouldn't already know
5. **Output format preferences** — templates, styles, formats required
6. **Existing patterns** — conventions or examples to follow

#### 1.2 Storage Locations

| Type | Path | Scope |
|------|------|-------|
| Project | `.cursor/skills/skill-name/` | Shared via VCS |
| Personal | `~/.cursor/skills/skill-name/` | All your projects |

Never create in `~/.cursor/skills-cursor/` (reserved for Cursor built-ins).

#### 1.3 SKILL.md Structure

Required YAML frontmatter:

| Field | Constraints | Purpose |
|-------|-------------|---------|
| `name` | Max 64 chars, lowercase letters/numbers/hyphens | Unique identifier |
| `description` | Max 1024 chars, non-empty | Discovery — agent decides when to apply |

Body template:

```markdown
---
name: skill-name
description: Use when [specific triggering conditions]
---

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

#### 1.4 Writing Effective Descriptions

- Write in third person (injected into system prompt)
- Start with "Use when..." to focus on triggering conditions
- Include specific trigger terms and symptoms
- Include both WHAT (capabilities) and WHEN (trigger scenarios)
- **Never summarize the skill's workflow in the description** — this causes
  agents to shortcut past the actual skill body (CSO insight from superpowers)

```yaml
# BAD: Summarizes workflow — agent may follow description instead of reading skill
description: Use when executing plans — dispatches subagent per task with review

# GOOD: Just triggering conditions
description: Use when executing implementation plans with independent tasks
```

#### 1.5 Authoring Principles

1. **Concise is key** — under 500 lines for SKILL.md. The agent is smart;
   only add context it doesn't already have.
2. **Progressive disclosure** — essential info in SKILL.md, heavy reference
   in separate files. Keep references one level deep.
3. **Appropriate degrees of freedom** — high (text) for judgment calls,
   medium (pseudocode) for preferred patterns, low (scripts) for fragile ops.
4. **Keyword coverage** — use terms agents search for: error messages,
   symptoms, synonyms, tool names.

#### 1.6 Common Patterns

Brief description + one example each:

- **Template pattern** — output format templates
- **Examples pattern** — before/after or input/output examples
- **Workflow pattern** — step-by-step checklists
- **Conditional workflow** — decision-point branching
- **Feedback loop** — validation after each step

#### 1.7 Directory Layout

Three tiers:

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

#### 1.8 Anti-Patterns

- Vague skill names (`helper`, `utils`)
- Verbose explanations of things the agent already knows
- Too many options without a clear default
- Time-sensitive information
- Inconsistent terminology
- Windows-style paths

#### 1.9 Verification Checklist

- [ ] Description is specific, third-person, includes trigger terms
- [ ] Description does NOT summarize the skill's workflow
- [ ] SKILL.md body under 500 lines
- [ ] Consistent terminology throughout
- [ ] Examples are concrete, not abstract
- [ ] File references one level deep
- [ ] Progressive disclosure used for heavy content
- [ ] No time-sensitive information

---

## 2. `create-agent` Skill

### Metadata

```yaml
name: create-agent
description: >
  Guide users through creating custom Cursor subagents with effective system
  prompts. Use when creating a new subagent, setting up task-specific agents,
  or asking about .cursor/agents/ format.
```

### Sections (~200 lines total)

#### 2.1 Requirements Gathering

Infer from context or ask:

1. **Specialization** — what domain or task the agent focuses on
2. **Scope** — project (`.cursor/agents/`) vs personal (`~/.cursor/agents/`)
3. **Delegation triggers** — when the main agent should delegate to this one
4. **Constraints** — what the agent should NOT do

#### 2.2 Storage Locations

| Type | Path | Scope | Priority |
|------|------|-------|----------|
| Project | `.cursor/agents/name.md` | Shared via VCS | Higher |
| Personal | `~/.cursor/agents/name.md` | All projects | Lower |

Project-level wins on name conflict.

#### 2.3 Agent File Format

`.md` file with YAML frontmatter and markdown body (becomes the system prompt):

```markdown
---
name: agent-name
description: Specific description of when to delegate to this agent
---

You are a [role]. When invoked:
1. [First action]
2. [Second action]
...

[Detailed instructions, checklists, output format]
```

Required fields:

| Field | Constraints |
|-------|-------------|
| `name` | Lowercase letters and hyphens only |
| `description` | Specific — the AI uses this to decide when to delegate |

#### 2.4 Writing Effective Descriptions

- Specific trigger terms so the AI knows when to delegate
- Include "use proactively" for auto-delegation
- Describe the problem space, not the implementation

```yaml
# BAD
description: Helps with code

# GOOD
description: >
  Expert code review specialist. Proactively reviews code for quality,
  security, and maintainability. Use immediately after writing or
  modifying code.
```

#### 2.5 System Prompt Best Practices

Structure the body around:

1. **Role statement** — one sentence establishing identity and expertise
2. **"When invoked" steps** — numbered list of what to do first
3. **Review/analysis checklist** — what to check or produce
4. **Output format** — how to structure the response (priorities, categories)
5. **Constraints** — what NOT to do, scope boundaries

Keep prompts focused. A good agent does one thing well.

#### 2.6 Common Agent Archetypes

One concise example each:

- **Reviewer** — code quality, security, standards compliance. References
  project linter config and contribution guidelines.
- **Domain specialist** — database, API, infrastructure, ML. Deep knowledge
  of a specific tech area in the project.
- **Workflow specialist** — deployment, testing, migration. Knows the
  project's operational procedures.

#### 2.7 Integration with Vaxflow

Vaxflow ships three built-in agents:

- `vaxflow-executor` — implements tasks from approved plans
- `vaxflow-spec-reviewer` — validates implementation matches spec
- `vaxflow-quality-reviewer` — validates code quality standards

Custom agents complement these. Create a custom agent when:

- You need a specialist that doesn't exist in the built-in set
- You want project-specific review criteria beyond what the quality reviewer covers
- A workflow is complex enough to warrant a dedicated agent with a tailored prompt

Do NOT create agents that duplicate built-in functionality.

#### 2.8 Verification Checklist

- [ ] Description is specific with trigger terms
- [ ] System prompt has clear role statement
- [ ] "When invoked" steps are concrete
- [ ] Output format is defined
- [ ] File is in correct location (`.cursor/agents/` or `~/.cursor/agents/`)
- [ ] Name uses only lowercase letters and hyphens

---

## 3. Onboarding Enhancement

### Current Flow (unchanged)

- **Phase 1** — Discovery Sweep (scan AI config + codebase context)
- **Phase 2** — Team Discovery
- **Phase 3** — Scope & Language
- **Phase 4a-d** — Generate rules (project-context, code-quality-standards,
  development-commands, glossary)

### New Phases

#### Phase 5 — Skill & Agent Proposal (NEW)

After generating rules, analyze Phases 1-3 discoveries to propose
project-specific skills and agents.

**Skill proposal logic:**

| Discovery | Proposed Skill | Content |
|-----------|---------------|---------|
| Test framework detected (pytest, jest, cargo test, etc.) | `testing` | Exact test commands, config flags, fixture patterns, coverage setup |
| Build pipeline detected (Docker, CI, Makefile) | `build-deploy` | Build commands, deployment steps, environment config |
| Quality tools with non-trivial config | `linting` | Exact lint/format commands, project-specific rules |
| Scripts in package.json / Makefile / similar | `local-dev` | Local dev workflow — start, seed, migrate, env setup |

**Agent proposal logic:**

| Discovery | Proposed Agent | Content |
|-----------|---------------|---------|
| Linter configs + type checker + CONTRIBUTING.md | `project-reviewer` | Project-specific review criteria from actual config |
| Clear tech specialization (DB-heavy, API-heavy, ML) | `domain-specialist` | Deep knowledge of the project's primary tech area |

**Presentation format (suggest-and-confirm):**

```
Based on your project, I'd recommend creating:

Skills:
  1. testing — pytest commands, conftest patterns, coverage config
  2. local-dev — docker-compose workflow, seed data, env setup

Agents:
  1. project-reviewer — knows your eslint config + TypeScript strict mode

Would you like me to generate all of these, or would you like to
select specific ones?
```

Use `AskQuestion` tool with multi-select when available. Fall back to
conversational confirmation.

Only propose what the discoveries actually support — do not suggest
items speculatively.

#### Phase 6 — Generate Confirmed Skills & Agents (NEW)

For each confirmed item:

- **Skills** → `.cursor/skills/<name>/SKILL.md`
  - Populated from actual project discoveries, not generic templates
  - References real paths, commands, and config found in Phase 1
  - Follows the structure defined in the `create-skill` skill

- **Agents** → `.cursor/agents/<name>.md`
  - System prompt references actual project conventions
  - Follows the structure defined in the `create-agent` skill

#### Phase 7 — Confirm & Report (modified from Phase 5)

Expanded output includes all generated artifacts:

```
Vaxflow is set up for your project. Generated files:

Rules:
- .cursor/rules/project-context.mdc
- .cursor/rules/code-quality-standards.mdc
- .cursor/rules/development-commands.mdc

Skills:
- .cursor/skills/testing/SKILL.md
- .cursor/skills/local-dev/SKILL.md

Agents:
- .cursor/agents/project-reviewer.md

Next steps:
1. Review and adjust the generated files
2. Commit to version control
3. Start working: /research, /innovate, /plan
```

#### Incremental Updates (modified)

When `project-context.mdc` already exists and onboarding runs again, add
a new option to the existing menu:

```
e) Add/update project skills and agents
```

This triggers Phases 5-6 using the existing discovery data, without
regenerating rules.

### What Does NOT Change

- Phase 1-3 discovery logic — untouched
- Phase 4a-d rule generation — untouched
- Red Flags table — untouched (add new entries for skills/agents)
- Integration section — updated to mention skills/agents as outputs

### New Red Flags

| Red flag | Prevention |
|----------|------------|
| Proposing skills/agents without discovery evidence | Only propose what discoveries support |
| Generating generic template skills | Content must reference actual project paths and commands |
| Proposing too many skills/agents | Guideline: ~4 skills + ~2 agents max per onboarding run; fewer is better |
| Skipping user confirmation | Always present proposals before generating |

---

## Scope Boundaries

**In scope:**
- `create-skill` skill (~300 lines)
- `create-agent` skill (~200 lines)
- Onboarding Phases 5-7 additions (~80 lines added to existing file)
- New red flags and incremental update option in onboarding

**Out of scope:**
- TDD testing methodology for skills (that's superpowers' `writing-skills` territory)
- Changes to `framework.mdc`
- Changes to existing vaxflow agents (executor, reviewers)
- Changes to hooks or MCP configuration
- `create-rule` skill (Cursor built-in already handles this adequately)
