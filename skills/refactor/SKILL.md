---
name: refactor
description: >
  Analyze codebase for improvement opportunities. Use when the user wants to
  identify tech debt, code smells, or structural improvements.
---

# Refactor

Analyze codebase for consolidation and refactoring opportunities to improve clarity, consistency, and adherence to SOLID/DRY principles.

**Core principle**: analyze with evidence, recommend with priorities, implement nothing until planned.

## When This Skill Fires

- User says `/refactor`, "analyze for improvements", "find code smells", or similar
- When the user wants to identify tech debt or structural improvements
- AI detects code smells during other work and suggests refactoring

## Analysis Areas

### 1. Duplication Detection

- **Parallel module patterns**: Repeated structure across feature areas or services
- **External client usage**: Similar setup and call patterns for APIs or remote services
- **Data handling**: Duplicate parsing, serialization, or format conversion logic
- **File I/O**: Repeated file operations across modules
- **Error handling**: Repeated handling for the same classes of failures
- **Configuration**: Redundant settings and constants

### 2. Pattern Consistency

- **External clients**: Consistent patterns for creating and invoking service clients
- **Data formats**: Standardized extraction, transformation, and validation
- **File operations**: Consistent path handling and safe I/O
- **Error handling**: Standardized handling for external dependency failures
- **Logging**: Consistent logging patterns (if logging is used)
- **Validation**: Consistent validation approaches across layers

### 3. Architecture Review

- **Module organization**: Layout of primary packages and layers
- **Module cohesion**: Single responsibility adherence
- **Dependency flow**: How modules depend on each other
- **File size**: Oversized files needing decomposition
- **Separation of concerns**: Clear boundaries between domains, shared libraries, and entry points

### 4. SOLID/DRY Violations

- **Single Responsibility**: Classes or modules doing too much
- **Open/Closed**: Modification vs extension opportunities
- **Interface Segregation**: Focused interfaces for external services, validation, and I/O
- **Dependency Inversion**: Abstractions vs concretions
- **Code reuse**: Opportunities to extract common functionality

## Project-Specific Analysis

Refer to your project's `project-context.mdc` for domain-specific modules and `code-quality-standards.mdc` for project-specific anti-patterns.

## Output Format

### Executive Summary
- Key findings (3-5 major issues)
- Priority ranking (High/Medium/Low impact & effort)

### Detailed Findings
For each issue:
1. **Problem**: What's wrong + code example
2. **Solution**: Specific fix + code example
3. **Benefits**: What improves
4. **Priority**: Impact/Effort/Risk (H/M/L)

### Implementation Roadmap
- **Phase 1**: Quick wins (low effort, high impact)
- **Phase 2**: Structural improvements (medium effort, high impact)
- **Phase 3**: Optimizations (high effort, medium impact)

## Anti-Patterns to Flag

- God Classes (500+ lines)
- Long Methods (50+ lines)
- Long Parameter Lists (5+ params)
- Shotgun Surgery (one change = many files)
- Duplicate Code
- Magic Numbers/Strings
- Dead Code

## Refactoring Safety

Before refactoring:
1. Ensure the project's test suite / validation passes
2. Run project-specific quality checks (see `development-commands.mdc`)

After refactoring:
1. Verify same functionality works
2. Check code quality standards maintained
3. Ensure no regressions introduced

## Integration

- **References**: `project-context.mdc`, `code-quality-standards.mdc`, `development-commands.mdc`
- **Leads to**: `plan` skill (when refactoring scope is defined), `innovate` skill (when exploring approaches)
