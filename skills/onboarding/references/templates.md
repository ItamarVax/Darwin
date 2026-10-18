# Onboarding Rule Templates

The templates Phase 4 of the `onboarding` skill fills in. Each file goes in
the project's `.cursor/rules/` directory. Replace every `[...]` placeholder
with content drawn from the discovery sweep and the user's answers — never
with invented content. Omit a section entirely when there is nothing real to
put in it.

**No generated overviews.** Do not add project overviews, module maps, entry
point lists, or architecture summaries to any template. Generated overviews
cost context on every request and go stale; the model reads the code, and
behavior files (`.darwin/behaviors/`) carry the "what lives where" role.

## `project-context.mdc`

Only what the model cannot learn quickly from the code itself.

```markdown
---
title: "Project Context"
description: "Project-specific context for Darwin framework"
alwaysApply: true
---

# Project Context

## Conventions & Gotchas
[Generated from CONTRIBUTING.md, existing AI config, and the scan — only non-standard conventions and traps a newcomer would hit. e.g., "Migrations are generated, never hand-written", "Tests need the local Postgres from docker-compose", "`src/legacy/` is frozen — new code goes in `src/core/`". Omit anything a standard tool or the code already makes obvious.]

## Project-Specific Safety
[Generated from team context and conventions — e.g., "Never modify generated files", "Preserve API backward compatibility"]

## Team Context
[Generated from team file if selected, otherwise omitted]
```

## `code-quality-standards.mdc`

```markdown
---
title: "Code Quality Standards"
description: "Project-specific code quality rules for Darwin framework"
alwaysApply: true
---

# Code Quality Standards

## Import Standards
[Generated from detected conventions — e.g., "absolute imports only" for Python, "path aliases" for TypeScript]

## Type Annotations
[Generated from detected type checker config and user quality priorities]

## Formatting
[Generated from detected formatter config — e.g., "prettier with default config", "ruff format"]

## Linting
[Generated from detected linter config — e.g., "eslint with airbnb config", "ruff check"]

## Quality Commands
[Generated from detected tools — exact commands to run for quality checks]
```

## `development-commands.mdc`

The human-readable view of the commands saved to `.darwin/config.json` in
Phase 3.5. The two must agree: `Testing`, `Linting`, `Type Check` and `Run`
use exactly the `commands.*` values (with `{files}` shown as a file list).

```markdown
---
title: "Development Commands"
description: "Project-specific development commands for Darwin framework"
alwaysApply: false
---

# Development Commands

Machine-readable copy: `.darwin/config.json` (`commands`). Change both together.

## Setup
[Generated from package manager detection — e.g., "npm install", "pip install -r requirements.txt"]

## Testing
[`commands.test` — full suite, e.g., "pytest -q"]
[`commands.testScoped` — selected files, e.g., "pytest -q <files>"]
[If no test command: "No test setup — feature and bugfix work runs in reduced mode."]

## Linting
[`commands.lint`, plus the formatter command if one is configured]

## Type Check
[`commands.typecheck`]

## Build
[Generated from detected build config — e.g., "npm run build", "cargo build"]

## Run
[`commands.run` — how to start the application locally]
```

## `glossary.mdc` (optional)

Only generate if team context or domain documentation provides terminology.
Otherwise skip.

```markdown
---
title: "Glossary"
description: "Domain terminology for this project"
alwaysApply: false
---

# Glossary

| Term | Definition |
|---|---|
| [term] | [definition from team context / documentation] |
```
