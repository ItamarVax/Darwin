# Cursor CLI Support

> **Scope**: this document is for the `cursor-agent` CLI only. Claude
> Code installs Darwin via its own plugin marketplace (see README) and
> does **not** need any of these symlink scripts.

The Cursor IDE Agent loads Darwin's rules, skills, and agents
automatically through the plugin system. The `cursor-agent` CLI does
not — it only sees:

- Project-scoped rules: `<project>/.cursor/rules/*.mdc`
- User-scoped skills: `~/.cursor/skills/*/SKILL.md`
- User-scoped agents: `~/.cursor/agents/*.md`

This document captures the symlink workarounds Darwin uses to bridge
that gap. **None of this is needed if you only use Darwin from the
IDE.** Skip this page entirely in that case.

## What gets symlinked, and why

| Category | Source (plugin) | Destination | Scope |
|----------|-----------------|-------------|-------|
| Skills | `<plugin>/skills/*` | `~/.cursor/skills/*` | One-time, user |
| Agents | `<plugin>/agents/*.md` | `~/.cursor/agents/*.md` | One-time, user |
| Framework rule | `<plugin>/rules/framework.mdc` | `<project>/.cursor/rules/framework.mdc` | Per-project |

`<plugin>` is wherever this repo is checked out, e.g.
`~/.cursor/plugins/local/darwin`. The scripts auto-detect it from
their own location, so the plugin can live anywhere.

## Quick start

From the plugin root, do the one-time machine setup:

```bash
bash scripts/cli-support-enable.sh
```

Then, in each project where you want Darwin available to the CLI:

```bash
~/.cursor/plugins/local/darwin/scripts/cli-link-framework.sh
```

To undo everything:

```bash
# In a project: remove the framework rule symlink
~/.cursor/plugins/local/darwin/scripts/cli-unlink-framework.sh

# Machine: remove all plugin symlinks from ~/.cursor/{skills,agents}
bash ~/.cursor/plugins/local/darwin/scripts/cli-support-disable.sh
```

All four scripts are idempotent — re-running them is safe.

**Upgrading to Darwin 5:** the agents `darwin-spec-reviewer` and
`darwin-quality-reviewer` were replaced by `darwin-checker` and
`darwin-maintainer-reviewer`, and a new `behaviors` skill was added. Re-run
`cli-support-disable.sh` and then `cli-support-enable.sh` so the old agent
symlinks (now dangling) are removed and the new agents and skill are linked.
Skills' `references/` folders come along automatically, because whole skill
directories are linked.

## Script reference

### `scripts/cli-support-enable.sh`

Symlinks every directory under `<plugin>/skills/` into
`~/.cursor/skills/` and every `.md` file under `<plugin>/agents/` into
`~/.cursor/agents/`.

- Creates `~/.cursor/skills` and `~/.cursor/agents` if missing.
- Skips destinations that already point to the right source (no-op).
- Refuses to overwrite real files or symlinks pointing elsewhere;
  reports them as conflicts and exits non-zero. Resolve manually.

### `scripts/cli-support-disable.sh`

Removes only symlinks under `~/.cursor/skills/` and `~/.cursor/agents/`
whose targets begin with this plugin's `skills/` or `agents/`
directory. Hand-authored skills, agents, and symlinks pointing
elsewhere are left alone.

### `scripts/cli-link-framework.sh`

Run from the root of a target project. Creates
`<project>/.cursor/rules/framework.mdc` as a symlink to
`<plugin>/rules/framework.mdc`, and appends an entry to `.gitignore`
so the symlink isn't committed. Refuses to overwrite a real file at
the destination. Refuses to run outside a git repository.

### `scripts/cli-unlink-framework.sh`

Run from the root of a target project. Removes the framework.mdc
symlink if it points into this plugin. Does **not** modify
`.gitignore`.

## Why this exists

User Rules in Cursor Settings only apply to the IDE Agent (Chat). The
CLI reads project-scoped `.cursor/rules/*.mdc` and the user-scoped
`~/.cursor/` directories — there is no documented user-level rules
file or plugin-level loader that `cursor-agent` honors. Symlinking the
plugin's resources into those well-known locations is the supported
pattern until Cursor adds CLI parity for plugins.

The framework rule is symlinked rather than copied so all projects
pick up plugin updates automatically — there is a single source of
truth.
