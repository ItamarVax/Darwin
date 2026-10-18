---
name: onboarding
description: >
  Set up Darwin for a new project by discovering existing conventions, scanning for
  AI configuration, generating project-specific rules, saving the project's test and
  quality commands, setting up tests when none exist, and capturing initial behavior
  files. Use when starting Darwin in a new repository, when the user says "set up
  Darwin" or "set up Darwin 5", or when project-context.mdc is missing.
---

# Onboarding

Discover a project's conventions and generate Darwin configuration files so the
framework works with any codebase, any language, any team.

**Core principle**: discover first, ask targeted questions, then generate minimal config.

## When This Skill Fires

- User says "set up Darwin for this project" or similar
- Darwin framework is installed but `.cursor/rules/project-context.mdc` does not exist
- User enters any RIPER mode and no project-context.mdc is found
- User asks to "set up Darwin 5" in a project onboarded earlier (go to Incremental Updates, option e)

## Phase 1 — Discovery Sweep

Scan the project root for existing configuration. Check each location and record what you find.

### AI Configuration

| Location | What to look for |
|---|---|
| `.cursor/rules/` | Existing Cursor rules (`.mdc` files) |
| `.cursor/agents/` | Existing Cursor agent definitions |
| `.cursor/skills/` | Existing Cursor skills |
| `AGENTS.md` | Cursor/Codex agent boot instructions |
| `CLAUDE.md` | Claude Code project instructions |
| `.agent/` | Superpowers-style agent config |
| `.agent/memory/` | Team memory, constitution, general context |
| `.agent/memory/teams/` | Team-specific context files |
| `.agent/skills/` | Superpowers skills |
| `.agent/agents/` | Superpowers agent definitions |
| `.github/copilot-instructions.md` | GitHub Copilot instructions |
| `.codex/` | Codex configuration |
| `cursorrules` or `.cursorrules` | Legacy Cursor rules |

### Codebase Context

| Location | What to look for |
|---|---|
| `README.md` | Project description, setup instructions |
| `ARCHITECTURE.md` | Architecture documentation |
| `CONTRIBUTING.md` | Contribution guidelines, code standards |
| `docs/` | Documentation directory |
| `pyproject.toml` | Python project config (dependencies, tools) |
| `package.json` | Node.js project config |
| `Cargo.toml` | Rust project config |
| `go.mod` | Go module config |
| `pom.xml` / `build.gradle` | Java/Kotlin project config |
| `.editorconfig` | Editor configuration |
| Linter configs | `.eslintrc.*`, `ruff.toml`, `.golangci.yml`, etc. |
| Formatter configs | `.prettierrc`, `rustfmt.toml`, etc. |
| Type checker configs | `tsconfig.json`, `mypy.ini`, `pyrightconfig.json` |

### What to Record

For each file found, note:
- **Path**: exact file path
- **Type**: AI config / project config / documentation / quality tool
- **Key content**: brief summary of what it contains (don't dump full contents)

## Phase 2 — Team Discovery

If `.agent/memory/teams/` exists (or any team-structure config is found):

1. List the team files found
2. Ask the user:

```
Which team are you on?

a) [Team 1 name — from filename]
b) [Team 2 name — from filename]
c) [Team 3 name — from filename]
d) None / I work across teams
e) This project doesn't have teams
```

3. If a team is selected, read the team file in full — it contains domain context, file structure, API endpoints, feature flags, and other team-specific information.

If no team structure is found, skip this phase.

## Phase 3 — Scope & Language

Present your findings summary and ask targeted questions.

### 3a. Present Findings

Summarize what you discovered:

```
I found the following in your project:

**Languages**: [detected from config files]
**Build/Package**: [tools detected]
**Quality tools**: [linters, formatters, type checkers]
**AI config**: [existing AI configuration found]
**Team context**: [team info if found]
**Documentation**: [docs found]
```

### 3b. Ask About Scope

```
What is the primary work area for this Darwin setup?

a) Full project (all directories)
b) Specific area: [suggest based on team context or project structure]
c) Let me specify: [free text]
```

### 3c. Ask About Quality Priorities

```
Which quality standards matter most for this project? (select all that apply)

a) Strict type annotations (all function signatures)
b) Import organization rules
c) Specific linting rules (auto-detected: [list tools found])
d) Formatting standards (auto-detected: [list tools found])
e) Other: [free text]
```

## Phase 3.5 — Commands

Detect the commands Darwin runs itself. Skills, scripts, and hooks read them from
`.darwin/config.json`; `development-commands.mdc` (Phase 4c) is the human-readable copy.

### 3.5a. Detect

Read, in order of trust: existing `.darwin/config.json` `commands`, then
`package.json` scripts / `Makefile` / `justfile` / `Taskfile.yml` targets, then
CI configs (`.github/workflows/`, `.gitlab-ci.yml`) for the commands CI actually
runs, then tool configs (the `fix-all` skill's detection table for lint and type
check; `pytest.ini` / `[tool.pytest]`, `jest.config.*`, `vitest.config.*`,
`Cargo.toml`, `go.mod` for tests).

| Key | What it is | Examples |
|---|---|---|
| `test` | Full test suite | `pytest -q`, `npm test`, `go test ./...`, `cargo test` |
| `testScoped` | Only the given tests; `{files}` = space-separated file list | `pytest -q {files}`, `npx vitest run {files}` |
| `lint` | Lint; `{files}` when the tool accepts a file list | `ruff check {files}`, `npx eslint {files}` |
| `typecheck` | Type check | `pyright`, `npx tsc --noEmit`, `mypy .` |
| `run` | Start the application locally | `npm run dev`, `uvicorn app.main:app --port 8000` |

Prefer the project's own wrapper (`npm test`, `make test`, `uv run pytest`) over
calling the tool directly — it carries the project's flags and environment.
Record only commands you found evidence for. Never guess a command.

### 3.5b. Confirm

Show the five keys with the detected command (or "none found"; `testScoped` shows
"falls back to test") and ask: **a) Looks right · b) Change some: [free text]**.

### 3.5c. Write `.darwin/config.json`

The file's contract is the `execute` skill's **Darwin Config** section — follow
it for key names and meaning.

1. If the file exists, read it and **merge**: set only the confirmed `commands.*`
   keys and `behaviors.enabled: true`. Preserve every other key (`profile`,
   `learnings`, `checker`, `commands.timeoutSec`, …) unchanged. If the file is
   not valid JSON, stop and show the user the parse error — do not overwrite it.
2. If it does not exist, create `.darwin/` and write only `commands` (the confirmed
   keys) and `"behaviors": { "enabled": true }`.
3. Omit every command that was not found. A missing `commands.test` is how Darwin
   detects "no test setup" — never write a placeholder or an empty string.

When Phase 3.6 adds a test command later, merge it the same way.

## Phase 3.6 — Test Setup

Run only when Phase 3.5 found no `commands.test`, or the test command finds no
tests. Otherwise skip.

Follow [references/test-setup.md](references/test-setup.md): propose the
standard framework for the language, one passing smoke test, and the commands to
save. **Ask before installing anything.** If the user declines, leave
`commands.test` unset and tell them feature and bugfix work will run in reduced
mode, with the offer repeated at the next feature.

## Phase 4 — Generate Configuration

Generate the following files in the project's `.cursor/rules/` directory. Create the directory if it doesn't exist.

The templates are in [references/templates.md](references/templates.md). Read it
before generating. Fill each placeholder only from discovery and user input.

| File | Contents | Always? |
|---|---|---|
| 4a. `project-context.mdc` | Conventions & Gotchas, Project-Specific Safety, Team Context | Yes |
| 4b. `code-quality-standards.mdc` | Imports, types, formatting, linting, quality commands | Yes |
| 4c. `development-commands.mdc` | Setup, testing, linting, type check, build, run | Yes |
| 4d. `glossary.mdc` | Domain terms | Only if team context or docs provide terminology |

**No generated overviews.** `project-context.mdc` holds only non-standard conventions,
gotchas, and safety rules — never overviews, module lists, or architecture summaries.

**Keep commands in sync.** `development-commands.mdc` uses exactly the
`commands.*` values written to `.darwin/config.json` in Phase 3.5 (and 3.6).
Whenever one changes, change the other — then re-run Phase 4.5.

> **Note (Cursor CLI)**: Darwin's framework rule, skills, and agents
> load automatically in the IDE Agent via the plugin system. If the user
> mentions using `cursor-agent` (the Cursor CLI), refer them to
> `CLI-SUPPORT.md` at the plugin root for the additional symlink setup —
> do not perform it as part of project onboarding.

## Phase 4.5 — Assemble CLAUDE.md Managed Block

Claude Code does not read `.cursor/rules/*.mdc`. To make the rules
generated in Phase 4 visible to Claude Code, assemble their bodies into
a managed block inside the project's `CLAUDE.md`.

### Assembly rules

1. **Source**: every `.mdc` file generated in Phase 4 (`project-context.mdc`,
   `code-quality-standards.mdc`, `development-commands.mdc`, and
   `glossary.mdc` if generated), in that order.
2. **Strip frontmatter**: for each source file, drop the leading YAML
   block (the lines from the first `---` through the matching closing
   `---`). Keep only the markdown body that follows.
3. **Concatenate**: join the bodies with a single blank line between
   each file. Do not add a synthetic heading per file — each `.mdc`
   body already starts with its own `#` heading.

### Block format

The assembled content goes between these exact markers:

```
<!-- BEGIN DARWIN (generated — do not edit between markers) -->
[assembled bodies here]
<!-- END DARWIN -->
```

**Detection rule**: when checking whether `CLAUDE.md` already contains a managed block, search for the literal prefix `<!-- BEGIN DARWIN` and the literal `<!-- END DARWIN -->` end marker. References to "the marker" elsewhere in this skill (Red Flags, Integration) use the abbreviated `<!-- BEGIN DARWIN -->` form for brevity; the actual marker written to disk is the full parenthetical form shown in the fence above.

### Writing the block

- **If `CLAUDE.md` does not exist**: create it containing only the
  block (markers + assembled content), with a trailing newline.
- **If `CLAUDE.md` exists and already contains both markers**: replace
  everything between the markers (inclusive of the marker lines) with
  a freshly assembled block. Content outside the markers is preserved
  byte-for-byte.
- **If `CLAUDE.md` exists and does not contain the markers**: append
  the block to the end of the file. If the existing file does not end
  with a newline, add one before the block.
- **If `CLAUDE.md` contains only one of the two markers, or the markers
  appear in the wrong order**: stop and warn the user — the file is in
  an inconsistent state, manual intervention is needed.

The block must always be regenerated as a unit; never patch its
interior in place.

## Phase 5 — Skill & Agent Proposal

After generating rules, analyze Phases 1-3 discoveries to propose
project-specific skills and agents.

### Skill Proposal Logic

| Discovery | Proposed Skill | Content |
|-----------|---------------|---------|
| Test framework detected (pytest, jest, cargo test, etc.) | `testing` | Exact test commands, config flags, fixture patterns, coverage setup |
| Build pipeline detected (Docker, CI, Makefile) | `build-deploy` | Build commands, deployment steps, environment config |
| Quality tools with non-trivial config | `linting` | Exact lint/format commands, project-specific rules |
| Scripts in package.json / Makefile / similar | `local-dev` | Local dev workflow — start, seed, migrate, env setup |

### Agent Proposal Logic

| Discovery | Proposed Agent | Content |
|-----------|---------------|---------|
| Linter configs + type checker + CONTRIBUTING.md | `project-reviewer` | Project-specific review criteria from actual config |
| Clear tech specialization (DB-heavy, API-heavy, ML) | `domain-specialist` | Deep knowledge of the project's primary tech area |

### Presentation

Present proposals using the structured question tool (`AskQuestion` on Cursor, `AskUserQuestion` on Claude Code) with multi-select when available, fall
back to conversational confirmation:

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

Only propose what the discoveries actually support — do not suggest items
speculatively. Guideline: ~4 skills + ~2 agents max per onboarding run; fewer
is better.

## Phase 6 — Generate Confirmed Skills & Agents

For each confirmed item, generate the file in the appropriate location:

- **Skills** → `.cursor/skills/<name>/SKILL.md`
  - Populated from actual project discoveries, not generic templates
  - References real paths, commands, and config found in Phase 1
  - Follows the structure defined in the `create-skill` skill

- **Agents** → `.cursor/agents/<name>.md`
  - System prompt references actual project conventions
  - Follows the structure defined in the `create-agent` skill

Create the `.cursor/skills/` and `.cursor/agents/` directories if they don't exist.

### Mirror to `.claude/` via symlinks

Claude Code reads `.claude/skills/` and `.claude/agents/`, not the
`.cursor/` equivalents. To make the same files visible to both hosts
without duplication, create directory symlinks:

- `.claude/skills` → `../.cursor/skills`
- `.claude/agents` → `../.cursor/agents`

Always create both links, even if Phase 6 generated zero skills or
zero agents — the directories may be empty now and populated later.

**Safety stance** (mirrors `scripts/cli-link-framework.sh`):

1. Ensure `.claude/` exists (`mkdir -p .claude`).
2. For each link destination (`.claude/skills`, `.claude/agents`):
   - If it is already a symlink pointing at the correct relative
     target → no change.
   - If it is a symlink pointing elsewhere → update it
     (`ln -sfn ../.cursor/<name> .claude/<name>`).
   - If it exists and is **not** a symlink → refuse and warn the
     user. Do not overwrite a real directory or file.
   - If it does not exist → create the symlink.
3. Make the `.cursor/<name>` target directory first if it does not
   already exist (an empty directory is fine — the symlink should
   still be created so future generations land in both views).

## Phase 6.5 — Initial Behaviors

Behavior files (`.darwin/behaviors/<capability>.md`) record what the product does, one
file per capability. Onboarding captures a few core ones; the first feature to touch an
area captures the rest. Format: the `behaviors` skill's
[formats reference](../behaviors/references/formats.md) — read it before drafting.

### 6.5a. Propose Capabilities

From the Phase 1 scan, list the repo's main **user-facing** capabilities — API
route groups, CLI commands, UI areas, jobs, features named in the README — each
with suggested `paths`. A capability is an area of behavior ("export", "auth"),
not a code folder. Propose 3–7; recommend 1–3 core ones.

```
Behavior files record what each part of the product does, so Darwin can keep
changes honest. Which capabilities should I capture now? (select any, or none)

1. export — paths [src/export/, src/api/export_routes.py] (recommended)
2. auth — paths [src/auth/]
3. scan-scheduling — paths [src/scheduler/]
```

Use the structured question tool with multi-select when available.

### 6.5b. Draft

For each pick, follow the `behaviors` skill's `/behaviors capture` steps:
read the code under `paths` and the tests that exercise it, then write
`.darwin/behaviors/<capability>.md`:

- every requirement `Status: observed` — the code may encode a bug, and only a
  human makes a requirement `intended`;
- `Tests:` points at existing tests that check the requirement, or says `none yet`;
- what, never how — no class names or algorithms; about 150 lines at most.

### 6.5c. Review

Show each draft and offer `/behaviors confirm <capability>` to walk its
requirements and promote the right ones to `intended`. The user may defer.

### 6.5d. Always Create the Directory

Create `.darwin/behaviors/` even if the user picked nothing — its existence
turns the drift check on. If it is empty, add an empty `.darwin/behaviors/.gitkeep`
so the directory survives the commit.

## Phase 7 — Confirm & Report

After generating all files:

1. List every file created with its path
2. Summarize what was configured
3. Suggest next steps:

```
Darwin is set up for your project. Generated files:

Rules (canonical, Cursor-shaped):
- `.cursor/rules/project-context.mdc` — conventions, gotchas, and safety rules
- `.cursor/rules/code-quality-standards.mdc` — quality rules and commands
- `.cursor/rules/development-commands.mdc` — development workflow commands
- `.cursor/rules/glossary.mdc` — domain terminology (if generated)

Claude Code view of rules:
- `CLAUDE.md` — managed `<!-- BEGIN DARWIN -->` block assembled from the rules above

Skills (canonical) + Claude Code symlink:
- `.cursor/skills/<name>/SKILL.md` — generated skill(s)
- `.claude/skills` → `.cursor/skills` (symlink, so Claude Code sees the same files)

Agents (canonical) + Claude Code symlink:
- `.cursor/agents/<name>.md` — generated agent(s)
- `.claude/agents` → `.cursor/agents` (symlink, so Claude Code sees the same files)

Darwin config and behaviors (both hosts):
- `.darwin/config.json` — test, lint, type-check and run commands; behaviors enabled
- `.darwin/behaviors/<capability>.md` — captured capabilities (all `observed` until confirmed)
- Test setup: [framework + smoke test added | already present | skipped — reduced mode]

Next steps:
1. Review and adjust the generated files as needed (edit `.cursor/rules/*.mdc`,
   then re-run onboarding to refresh the `CLAUDE.md` managed block)
2. Commit the `.cursor/` files, `.claude/` symlinks, `CLAUDE.md`, `.darwin/config.json`,
   and `.darwin/behaviors/` to version control
3. Confirm observed behaviors when convenient: `/behaviors confirm <capability>`
4. Start working: `/research` to explore, `/innovate` to design, `/plan` to plan
```

## Incremental Updates

If `project-context.mdc` already exists and the user runs onboarding again:

1. Ask: "Project configuration already exists. What would you like to do?"
   - a) Regenerate from scratch (overwrites existing rules and refreshes the CLAUDE.md managed block)
   - b) Update specific sections
   - c) Add a new team/area context
   - d) Add/update project skills and agents
   - e) Set up Darwin 5 (commands, tests, behaviors)
   - f) Cancel

2. For option (b), show the current sections and let the user choose which to update.
   After editing any `.mdc` file, re-run Phase 4.5 to refresh the `CLAUDE.md`
   managed block. Content outside the markers is preserved.
3. For option (d), run Phases 5–6 using existing discovery data without regenerating
   rules. Phase 6 still runs the symlink step, which is idempotent on re-run.
4. For option (e), run only Phases 3.5, 3.6 and 6.5, scanning build and test config
   as needed, then report as in Phase 7. If `development-commands.mdc` exists,
   update it to match the saved commands and re-run Phase 4.5.
5. After any regeneration path, Phase 4.5 (CLAUDE.md block) and the Phase 6
   symlink step must run again — both are idempotent and safe to repeat.

## Red Flags

| Red flag | Prevention |
|---|---|
| Generating config without reading existing conventions | Always complete Phase 1 first |
| Asking too many questions at once | One question per phase, multiple-choice preferred |
| Generating overly detailed config | Keep each file focused — the user can always add more |
| Overwriting existing `.cursor/rules/` files | Always check and ask before overwriting |
| Making up project context | Only use information from scanned files and user input |
| Proposing skills/agents without discovery evidence | Only propose what discoveries support |
| Generating generic template skills | Content must reference actual project paths and commands |
| Proposing too many skills/agents | Guideline: ~4 skills + ~2 agents max; fewer is better |
| Skipping user confirmation for skills/agents | Always present proposals before generating |
| Editing inside the CLAUDE.md managed block by hand | Treat the block as generated output; edits will be lost on regeneration. Use the source `.mdc` files instead. |
| Generating CLAUDE.md when only one DARWIN marker is present | Stop and warn — file is in an inconsistent state. Do not auto-repair. |
| Overwriting a real `.claude/skills` or `.claude/agents` directory with a symlink | Always check for non-symlinks at the destination first; refuse and warn if found. |
| Skipping `.claude/` symlinks because Phase 6 generated nothing | Create the symlinks anyway — directories may be populated by later runs. |
| Generating an overview, module map, entry points, or architecture section | Never — `project-context.mdc` holds only conventions, gotchas, and safety rules |
| Guessing a command, or saving a placeholder `commands.test` | Save only commands found in the project or given by the user; missing means "no test setup" |
| Overwriting `.darwin/config.json` | Merge — preserve `profile` and every other existing key |
| Installing test dependencies without asking | Propose first; install only after the user agrees |
| Marking captured requirements `intended` | Onboarding drafts are all `observed`; only `/behaviors confirm` promotes them |
| Skipping `.darwin/behaviors/` because nothing was picked | Create it anyway — it turns the drift check on |

## Integration

- **Called by**: Framework detection (when project-context.mdc is missing); the session-start hook's "Set up Darwin 5" suggestion; the feature and bugfix tracks when they offer test setup ([references/test-setup.md](references/test-setup.md))
- **Produces**: Project-specific `.mdc` files under `.cursor/rules/`, a managed `<!-- BEGIN DARWIN -->` block in the project's `CLAUDE.md`, `.cursor/skills/` and `.cursor/agents/` (with `.claude/skills` and `.claude/agents` symlinks pointing at them), `.darwin/config.json` (commands, `behaviors.enabled`), and `.darwin/behaviors/`, consumed by all other Darwin components on both Cursor and Claude Code.
- **Pairs with**: `framework.mdc` (which references project-context.mdc and code-quality-standards.mdc)
- **Cross-references**: `execute` skill (Darwin Config — the `.darwin/config.json` contract), `behaviors` skill (behavior-file format, `/behaviors capture` and `/behaviors confirm`), `fix-all` skill (lint and type-check detection), `create-skill` skill (for skill structure), `create-agent` skill (for agent structure)
- **References**: [references/templates.md](references/templates.md) (rule templates), [references/test-setup.md](references/test-setup.md) (test setup)
