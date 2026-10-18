---
name: create-agent
description: >
  Guide users through creating custom Cursor subagents with effective system
  prompts. Use when creating a new subagent, setting up task-specific agents,
  or asking about .cursor/agents/ format.
---

# Creating Agents

Guide for authoring Cursor subagents — specialized AI assistants that run in
isolated contexts with custom system prompts.

## Before You Begin

Gather requirements before writing. Infer from conversation context when
possible. Otherwise ask using the structured question tool (`AskQuestion` on Cursor, `AskUserQuestion` on Claude Code) (fall back to conversational):

1. **Specialization** — what domain or task the agent focuses on
2. **Scope** — project (`.cursor/agents/`) vs personal (`~/.cursor/agents/`)
3. **Delegation triggers** — when the main agent should delegate to this one
4. **Constraints** — what the agent should NOT do

## Storage Locations

| Type | Path | Scope | Priority |
|------|------|-------|----------|
| Project | `.cursor/agents/name.md` | Shared via VCS | Higher |
| Personal | `~/.cursor/agents/name.md` | All projects | Lower |

Project-level wins on name conflict. Use project-level for codebase-specific
agents shared with the team. Use personal for agents you want across all
projects.

## Agent File Format

A `.md` file with YAML frontmatter and a markdown body. The body becomes the
agent's system prompt.

```yaml
---
name: agent-name
description: Specific description of when to delegate to this agent
---
```

### Required Fields

| Field | Constraints |
|-------|-------------|
| `name` | Lowercase letters and hyphens only |
| `description` | Specific — the AI uses this to decide when to delegate |

### Body Structure

```
You are a [role]. When invoked:
1. [First action]
2. [Second action]

[Review checklist / analysis steps]

[Output format expectations]

[Constraints — what NOT to do]
```

## Writing Effective Descriptions

The description determines when the main agent delegates work to your subagent.

- Use specific trigger terms so the AI knows when to delegate
- Include "use proactively" to encourage automatic delegation
- Describe the problem space, not the implementation

```yaml
# BAD: Too vague
description: Helps with code

# GOOD: Specific with proactive trigger
description: >
  Expert code review specialist. Proactively reviews code for quality,
  security, and maintainability. Use immediately after writing or
  modifying code.
```

## System Prompt Best Practices

### Structure Around Five Elements

1. **Role statement** — one sentence establishing identity and expertise
2. **"When invoked" steps** — numbered list of what to do first
3. **Review/analysis checklist** — what to check or produce
4. **Output format** — how to structure the response
5. **Constraints** — what NOT to do, scope boundaries

### Keep It Focused

A good agent does one thing well. If you're adding multiple unrelated
checklists, split into separate agents.

### Be Specific About Output

Tell the agent exactly how to present findings:

```markdown
Provide feedback organized by priority:
- **Critical**: Must fix before merge
- **Warning**: Should fix
- **Suggestion**: Consider improving

Include specific examples of how to fix each issue.
```

## Common Agent Archetypes

### Reviewer

```markdown
---
name: project-reviewer
description: >
  Project-specific code review specialist. Proactively reviews code for
  quality against project standards. Use after writing or modifying code.
---

You are a senior code reviewer for this project.

When invoked:
1. Run git diff to see recent changes
2. Focus on modified files
3. Begin review immediately

Review checklist:
- Code follows project conventions
- Proper error handling
- No exposed secrets or API keys
- Input validation implemented
- Test coverage adequate
- Performance considerations addressed

Provide feedback as:
- **Critical**: Must fix before merge
- **Warning**: Should fix
- **Suggestion**: Consider improving

Include specific fix examples for each issue.
```

### Domain Specialist

```markdown
---
name: database-expert
description: >
  Database specialist for schema design, query optimization, and
  migration safety. Use when working with database schemas, queries,
  or migrations.
---

You are a database specialist for this project.

When invoked:
1. Understand the data requirement
2. Review existing schema for context
3. Propose changes with migration safety

Key practices:
- Backwards-compatible migrations
- Index recommendations for query patterns
- Transaction safety for multi-step changes

For each recommendation:
- Explain the rationale
- Show the exact SQL or migration code
- Flag any risks or required coordination
```

### Workflow Specialist

```markdown
---
name: deploy-specialist
description: >
  Deployment workflow specialist. Use when deploying, debugging CI/CD
  pipelines, or preparing releases.
---

You are a deployment specialist for this project.

When invoked:
1. Check current deployment status
2. Review recent changes for deployment risks
3. Guide through the deployment process

Deployment checklist:
- All tests passing
- No breaking changes to APIs
- Database migrations reviewed
- Environment variables updated
- Rollback plan documented

Flag any risks before proceeding.
```

## Integration with Darwin

Darwin ships four built-in agents:

- `darwin-researcher` — investigates the codebase and writes the research artifact
- `darwin-executor` — implements tasks from approved plans
- `darwin-checker` — end-of-feature evaluation: runs the suite, mutation probes, and the app; grades each behavior ID
- `darwin-maintainer-reviewer` — end-of-feature review: would this repo's maintainers merge it?

Custom agents complement these. Create a custom agent when:

- You need a specialist outside the built-in set
- You want project-specific review criteria beyond the maintainer reviewer
- A workflow warrants a dedicated agent with a tailored prompt

Do NOT create agents that duplicate built-in functionality.

## Verification Checklist

- [ ] Description is specific with trigger terms
- [ ] System prompt has clear role statement
- [ ] "When invoked" steps are concrete
- [ ] Output format is defined
- [ ] File is in correct location (`.cursor/agents/` or `~/.cursor/agents/`)
- [ ] Name uses only lowercase letters and hyphens
- [ ] Agent does one thing well — not overloaded with responsibilities
