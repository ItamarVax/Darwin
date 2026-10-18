# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Darwin is a **dual-host plugin** (Cursor + Claude Code) that ships an AI workflow framework: five RIPER modes (Research, Innovate, Plan, Execute, Review) plus utility skills, four agents (researcher, executor, checker, maintainer reviewer), living behavior files with a strict drift check, an evolving learnings loop, lifecycle hooks, and an onboarding skill that sets up project commands, tests, behaviors, and rules. The design is `docs/specs/2026-10-18-darwin-5-design.md`. There is **no application code** — the "source" is markdown configuration (skills/agents/rules), bash scripts (hooks, install helpers), and plugin/MCP JSON.

End users install on Claude Code via:
```
/plugin marketplace add ItamarVax/darwin
/plugin install darwin@darwin
```
(The full URL `https://github.com/ItamarVax/darwin.git` or the SSH form `git@github.com:ItamarVax/darwin.git` works too.)
On Cursor, via the existing IDE plugin discovery (clone into `~/.cursor/plugins/`).

## How the framework loads (per host)

**Cursor IDE Agent** auto-discovers the plugin from `.cursor-plugin/plugin.json`. That manifest pins `hooks: "./hooks/hooks-cursor.json"` (Cursor event names: `sessionStart`, `sessionEnd`, `beforeShellExecution`). Skills, agents, and `mcp.json` are auto-discovered. `rules/framework.mdc` (with `alwaysApply: true`) carries the `[MODE: ...]` constitutional rule.

**Claude Code** auto-discovers `.claude-plugin/plugin.json` after a marketplace install. Skills/agents/`hooks/hooks.json`/`.mcp.json` are auto-discovered. `hooks/hooks.json` uses Claude event names (`SessionStart`, `SessionEnd`, `PreToolUse` with Bash matcher) and `${CLAUDE_PLUGIN_ROOT}` for script paths. Claude has no `alwaysApply` analog; the `skills/using-darwin/` skill carries the same constitutional rule and auto-fires on Darwin keywords.

**Cursor CLI (`cursor-agent`)** does not honor plugins — only `<project>/.cursor/rules/*.mdc`, `~/.cursor/skills/*/SKILL.md`, and `~/.cursor/agents/*.md`. The `scripts/cli-*.sh` helpers symlink the plugin's resources into those locations. Idempotent, refuse to clobber non-symlinks, detect the plugin location from their own path. See `CLI-SUPPORT.md` for the full surface; do not duplicate its content elsewhere. Claude Code does **not** need these scripts.

### MCP config is duplicated, not symlinked

`mcp.json` (Cursor) and `.mcp.json` (Claude Code) are two real files with identical content. Edits to one **must** be applied to the other. If you find you've changed only one, fix it before committing.

### Hook scripts are shared, but read different payload shapes

`hooks/lib.sh` exposes `detect_platform()` (returns `claude` when `CLAUDE_PLUGIN_ROOT` is set, else `cursor`), an extended `json_field` that accepts dotted paths via `jq` for Claude's nested `tool_input.command`, `project_root()` (payload `cwd` → `CLAUDE_PROJECT_DIR` → Cursor `workspace_roots[0]` → git toplevel — never trust the hook process's own cwd), and `emit_context()`, which writes `hookSpecificOutput.additionalContext` on Claude and `additional_context` on Cursor. Do not emit a Cursor `followup_message` from a hook unless you mean it: Cursor auto-submits it as the next user turn. Claude Code fires `UserPromptSubmit` for subagent reports and other non-human turns too, so never infer user intent from prompt text in a hook. `hooks/test-hooks.sh` pipes sample payloads for both hosts through every hook — run it after any hook change.

## Cross-host format mapping (live)

| Concept | Cursor | Claude Code |
|---|---|---|
| Plugin manifest | `.cursor-plugin/plugin.json` | `.claude-plugin/plugin.json` |
| Marketplace listing | n/a | `.claude-plugin/marketplace.json` |
| Constitutional rule | `rules/framework.mdc` (`alwaysApply: true`) | `skills/using-darwin/SKILL.md` (auto-fires on keywords) |
| Skill | `skills/<name>/SKILL.md` (shared) | `skills/<name>/SKILL.md` (shared) — invoked as `/darwin:<name>` |
| Agent | `agents/<name>.md` (shared) | `agents/<name>.md` (shared) |
| Hook config | `hooks/hooks-cursor.json` | `hooks/hooks.json` |
| Hook event names | `sessionStart`, `sessionEnd`, `beforeShellExecution` | `SessionStart`, `SessionEnd`, `PreToolUse` (matcher: `Bash`) |
| Hook script paths | relative (`./hooks/...`) | `${CLAUDE_PLUGIN_ROOT}/hooks/...` |
| MCP | `mcp.json` | `.mcp.json` |
| Plugin scripts from skills | resolved from the skill's directory (`<skill-dir>/../../scripts/...`) | `${CLAUDE_PLUGIN_ROOT}/scripts/...` |

## Editing skills, agents, and rules

These files are prompts that get loaded verbatim into another model's context. Changes have outsized effects:

- **Frontmatter is part of the contract.** Skills' `description` controls when they fire; agents' `description` controls when the parent dispatches them. Rewording these can silently change behavior.
- **Agents declare `model: sonnet` in frontmatter.** Claude Code honors it as the default dispatch model (per-dispatch `model` params in the skills override it); Cursor doesn't recognize the alias and silently falls back to its own default, so on Cursor the skills' per-dispatch mapping tables are the only routing mechanism. The tier→model mapping is profile-aware and lives in one place, `skills/execute/references/model-selection.md`, which `reviewing-implementation` links to.
- **Read-only agents are enforced, not just instructed.** `darwin-maintainer-reviewer` declares `disallowedTools: Write, Edit, NotebookEdit` (Claude Code) and `readonly: true` (Cursor); the researcher disallows `Edit`/`NotebookEdit` so it can only (over)write its one report file. Each host ignores the other's field. Keep these when editing agent frontmatter. `darwin-checker` is deliberately *not* read-only — it applies and reverts mutation probes; `reviewing-implementation` verifies a clean tree after it runs.
- **Single definitions — edit them, not copies.** `.darwin/config.json` contract: the `execute` skill's `## Darwin Config` section. Behavior-file, change-proposal, and `Behavior-Change` trailer formats: `skills/behaviors/references/formats.md` (parsed by `scripts/behavior-check.sh` — change both together). Progress-file schema, Status Vocabulary, and the `### Evaluation — ✅ Approved` / `❌ Escalated` headings: `skills/plan/references/progress-file.md`. Lesson and usage-log format: `skills/compound/references/lesson-format.md`.
- **Match the existing voice and structure.** Skills use a standard skeleton (When This Skill Fires / Constraints / Process / Integration). Agents declare strict rules and a fixed output format. Stay consistent across files when changing one.
- **The framework rule (`rules/framework.mdc`) requires every response to begin with `[MODE: NAME]`** — this applies to *users* of Darwin, not to Claude Code editing this repo. Do not prepend mode tags to your own responses.
- Skills are internally referenced by short slash names (`/research`, `/execute`, etc.). Renaming a skill directory means grepping for every cross-reference.

## Commit style

Commits follow conventional format with a Darwin-specific suffix when work is happening inside a numbered plan: `type(scope): Task N — title`. Outside of an active plan, use plain conventional commits. Recent history is the authoritative example — `git log --oneline -20`.

The automated checks are `bash hooks/test-hooks.sh` (hook behavior on both hosts) and `bash scripts/test-scripts.sh` (`behavior-check.sh` and `archive-change.sh` against throwaway repos). Scripts must stay compatible with bash 3.2 (the macOS default). Otherwise, verification is reading the affected markdown end-to-end and confirming cross-references still resolve.

## Things that look broken but aren't

- `.darwin/darwin-progress.md` exists inside a feature worktree (created at plan finalization) and is committed on the feature branch — the file tracks Darwin's *own* development plan, not user work. A `.darwin/active-worktree` breadcrumb at the main checkout root points sessions at the active worktree.
- `.worktrees/` is gitignored and used by the `using-git-worktrees` skill for feature isolation.
- The hooks under `hooks/` reference `./hooks/...` paths relative to the Cursor working directory — they're invoked by Cursor, not run manually.
- `.cursor/darwin-research.md` exists whenever the user has fired `/research` — it's the live findings artifact written by the `darwin-researcher` subagent, overwritten per session. Not a checked-in user document; the file may or may not be present at any given time.
- `.darwin/plans/` holds Darwin 4 plan archives. Darwin 5 archives finished changes to `.darwin/archive/<slug>/` (`plan.md` + `proposal.md`) via `scripts/archive-change.sh`. The framework never reads either; they're a human-readable record of shipped work. Slug derives from the git branch name.
- In a user project, `.darwin/behaviors/*.md` (behavior files), `.darwin/learnings/*.md` plus `.darwin/learnings/usage/*.jsonl` (lessons and per-branch usage logs), and `.darwin/config.json` are committed project state, not leftovers. `.darwin/proposal.md` exists in the main checkout between innovate and plan finalization, then moves into the feature worktree.
- Legacy paths are still read on purpose: `.cursor/darwin-learnings/` (migrated by `compound`, still honored by the session hooks) and the Darwin 4 `### Final Review — ✅ Review approved` heading (accepted by `finishing-development-branch` for in-flight plans).

## Dual-host onboarding output

The `onboarding` skill (in `skills/onboarding/`) is the one place in
this repo that generates per-project artifacts for **both** hosts in a
single run. The output shape is fixed and contributors changing the
skill must preserve it:

- **Rules**: canonical files live at `.cursor/rules/*.mdc`. Their
  bodies (frontmatter stripped) are also assembled into a managed
  block in the project's `CLAUDE.md`, bounded by these exact markers:

  ```
  <!-- BEGIN DARWIN (generated — do not edit between markers) -->
  ...
  <!-- END DARWIN -->
  ```

  The block is regenerated as a unit; content outside the markers is
  preserved. If only one marker is present, onboarding stops and
  warns rather than auto-repairing.

- **Skills and agents**: canonical files live at
  `.cursor/skills/<name>/SKILL.md` and `.cursor/agents/<name>.md`.
  `.claude/skills` and `.claude/agents` are directory symlinks
  pointing at the `.cursor/` siblings (`../.cursor/skills` and
  `../.cursor/agents`), so both hosts see the same files with no
  duplication. The symlink-creation step matches the safety stance in
  `scripts/cli-link-framework.sh`: idempotent, refuses to clobber a
  non-symlink that already exists.

Windows users may need `core.symlinks=true` (and Developer Mode or
admin rights) for the `.claude/` symlinks to clone correctly. This is
an accepted limitation — the project's user base is primarily
macOS/Linux.
