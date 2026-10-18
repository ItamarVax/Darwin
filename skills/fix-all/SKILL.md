---
name: fix-all
description: >
  Run the project's lint, format, and type-check tools on changed files and
  auto-fix what they can. Use before committing, when git-ship runs its
  quality check, or when the user says /fix-all.
---

# Fix All

Run all code quality checks and automatically fix linting, formatting, import, and type hint issues.

## When This Skill Fires

- User says `/fix-all`, "fix all", or "run quality checks and fix"
- Invoked by `git-ship` before committing

## When to Use

- Before committing changes
- After making code modifications
- Before creating a pull request
- After implementing changes in execute mode

## Scope: Changed Files Only

By default, run on the files this branch changed — never reformat the whole repository, which buries the real change in unrelated diff noise:

```bash
base=$(git merge-base HEAD origin/HEAD 2>/dev/null || git merge-base HEAD main)
{ git diff --name-only --diff-filter=d "$base"...HEAD
  git diff --name-only --diff-filter=d HEAD
  git ls-files --others --exclude-standard; } | sort -u
```

Pass that file list to each tool instead of `.`. Run on the whole repository only when the user explicitly asks (`/fix-all --all`). Project-wide tools that cannot take a file list (e.g. `tsc --noEmit`) run as usual, but only fix issues inside the scoped files and report the rest.

If the scoped list is empty, report "No changed files" and stop.

## Execution Flow

### 1. Detect Project Tools

**Configured commands first.** Read `commands.lint` and `commands.typecheck` from `.darwin/config.json` (see the `execute` skill's Darwin Config section for location and loading). Replace `{files}` with the scoped changed-file list (space-separated). A command without `{files}` runs as written, project-wide, under the scoping rule above. Respect `commands.timeoutSec`.

**Fallback detection.** Only for a category whose key is absent (or when the file is missing), scan the project for quality tool configuration:

| File/Config | Category | Suggested action |
|---|---|---|
| `pyproject.toml` with lint+format tooling | Lint, format | Run configured lint (with fix) and formatter |
| `.eslintrc.*` or `eslint.config.*` | Lint (JS/TS) | `npx eslint --fix <files>` |
| `prettier.config.*` or `.prettierrc` | Format (JS/TS) | `npx prettier --write <files>` |
| `Cargo.toml` | Lint, format (Rust) | `cargo clippy --fix && cargo fmt` |
| `.golangci.yml` | Lint (Go) | `golangci-lint run --fix` |
| `tsconfig.json` | Type-check (TS) | `npx tsc --noEmit` |
| Type-check config in `pyproject.toml` | Type-check | Run the matching checker |
| `pyrightconfig.json` | Type-check | `pyright <files>` |

If neither `.darwin/config.json` nor tool configuration yields a command, check `development-commands.mdc`.

Formatting has no config key; formatters always come from detection.

### 2. Run Quality Checks

Run detected tools on the scoped files, in order: lint → format → type-check.

### 3. Auto-Fix Issues

Apply auto-fixable issues. Report issues that require manual intervention.

### 4. Verification

Re-run checks to confirm all auto-fixes are clean.

## Fix Priority

1. **Critical**: Syntax errors, import errors, type errors
2. **High**: Lint violations, format issues, missing type hints
3. **Low**: Warnings, style suggestions

## Common Fix Patterns

Refer to your project's `code-quality-standards.mdc` for language-specific fix patterns.

## Limitations

Cannot auto-fix: Complex type inference, business logic errors, architectural issues

## Integration

- **Called by**: `git-ship` skill (pre-commit quality check)
- **Configured by**: `commands.lint`, `commands.typecheck`, `commands.timeoutSec` in `.darwin/config.json` (see the `execute` skill's Darwin Config section)
- **References**: `code-quality-standards.mdc`, `development-commands.mdc`
