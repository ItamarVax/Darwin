# Test Setup

Detail for Phase 3.6 of the `onboarding` skill. The feature and bugfix tracks
point here too when they offer test setup to a project that has none.

**Goal**: the smallest setup that gives the project a working `commands.test` —
the standard framework for the language, one smoke test that passes, and the
commands saved to `.darwin/config.json`. Nothing more: no coverage tooling, no
CI changes, no test reorganization.

## When to Run

- Phase 3.5 found no `commands.test`, or
- the detected test command finds zero tests (e.g. pytest exits `5`, "no tests
  ran") — then only the smoke test is needed, not a framework.

If a test command exists and finds tests, skip this phase.

## Standard Frameworks

Pick by the project's primary language and existing tooling. Prefer a framework
already present in the dependency files over this table.

| Language / stack | Framework | Install (dev dependency) | `commands.test` | `commands.testScoped` |
|---|---|---|---|---|
| Python (uv) | pytest | `uv add --dev pytest` | `uv run pytest -q` | `uv run pytest -q {files}` |
| Python (poetry) | pytest | `poetry add --group dev pytest` | `poetry run pytest -q` | `poetry run pytest -q {files}` |
| Python (pip) | pytest | `pip install pytest` + add to the dev requirements file | `pytest -q` | `pytest -q {files}` |
| TypeScript / Vite / ESM | Vitest | `npm install -D vitest` (match the lockfile's package manager) | `npx vitest run` | `npx vitest run {files}` |
| JavaScript (CommonJS) | Jest | `npm install -D jest` | `npx jest` | `npx jest {files}` |
| Node, no installs wanted | `node:test` (built in) | none | `node --test` | `node --test {files}` |
| Go | `go test` (built in) | none | `go test ./...` | `go test {files}` (pass package dirs) |
| Rust | `cargo test` (built in) | none | `cargo test` | `cargo test` (no file scoping) |
| Java / Kotlin (Maven) | JUnit 5 | `junit-jupiter` test dependency in `pom.xml` | `mvn -q test` | `mvn -q test -Dtest={files}` (class names) |
| Java / Kotlin (Gradle) | JUnit 5 | `testImplementation` JUnit 5 + `useJUnitPlatform()` | `./gradlew test` | `./gradlew test --tests {files}` (class names) |
| Ruby | RSpec | `bundle add rspec --group test` | `bundle exec rspec` | `bundle exec rspec {files}` |

When the scoped form needs something other than file paths (class names,
package dirs), say so to the user and save it anyway — or omit `testScoped`
and let it fall back to `test`.

If a `package.json` `test` script exists, save `npm test` (or the lockfile's
package-manager equivalent) instead of calling the framework directly.

## The Smoke Test

One test file, in the location the framework expects (`tests/test_smoke.py`,
`src/smoke.test.ts`, `smoke_test.go` in the main package, `tests/smoke.rs`,
etc.).

- It exercises **real project code** — import the main module and call one
  small, side-effect-free public function, or assert a public constant. Never
  `assert True`.
- It needs no network, database, or secrets.
- It must **pass**. If the only importable code needs external services, assert
  that the module imports and stop there.

## Process

1. **Propose** — one message, nothing written yet:

   ```
   This project has no test setup. Darwin's feature and bugfix tracks use
   tests as the contract, so I'd like to add a minimal one:

   Framework: [framework] ([why: standard for <language> / already in deps])
   Install:   [exact command, or "nothing — built in"]
   Smoke test: [path] — [what it checks]
   Commands saved to .darwin/config.json:
     test:       [command]
     testScoped: [command]

   a) Set it up
   b) Set it up with changes: [free text]
   c) Skip for now
   ```

2. **Ask before installing anything.** Never run an install command, edit a
   dependency file, or write the smoke test before the user picks (a) or (b).
3. **On yes**:
   - run the install command (if any);
   - write the smoke test;
   - run `commands.test` and confirm it passes — if it fails, fix the smoke test
     or the setup, never application code; after two failed attempts, show the
     output and ask the user;
   - merge `commands.test` (and `commands.testScoped`) into `.darwin/config.json`
     per Phase 3.5, and update the `Testing` section of `development-commands.mdc`.
4. **On skip**:
   - leave `commands.test` **unset** — never save a placeholder or a command
     that does not work;
   - tell the user, in one line: "Skipped. Feature and bugfix work will run in
     reduced mode (no test-first wave; tasks are gated on acceptance checks),
     and Darwin will offer test setup again at the next feature."

## Constraints

- Ask before installing dependencies or editing dependency files.
- One framework, one smoke test. Do not write tests for existing behavior here —
  that happens per feature, and behavior files record what to test.
- Do not change application code to make it testable.

## Committing the setup

When this step runs during onboarding, the user commits the outputs with the
rest of onboarding's files. When it runs from another skill (`plan`,
`systematic-debugging`), that skill commits the setup files — the framework
config, the smoke test, dependency manifest changes, `.darwin/config.json`, and
`development-commands.mdc` — as their own commit, `chore(test): set up test
suite`, before any feature or fix work, with the user's go-ahead.
