---
name: review
description: >
  Review completed work for correctness and quality. Use when implementation
  is done and needs verification before finishing.
---

# Review

> Begin every reply with `[MODE: REVIEW]`. See `using-darwin` for the full contract.

Validating implementation against the plan and ensuring quality standards.

**Core principle**: verify everything. Compare actual changes against the plan, check quality, document deviations.

## When This Skill Fires

- User says `/review`, "let's review", "validate the changes", or similar
- After completing implementation outside of execute mode
- When verifying changes match an approved plan
- Before committing or merging changes
- When conducting quality assurance on completed work

Note: During execute mode, the `reviewing-implementation` skill handles review automatically. This standalone review skill is for use outside of the execute workflow.

## Constraints

- **Allowed**: Reviewing code, checking quality, documenting deviations, running quality checks
- **Forbidden**: Making new changes (unless minor fixes to address review findings)

## Review Process

1. **Plan Comparison**: Compare implementation against approved plan
2. **Checklist Validation**: Verify all planned steps were completed
3. **Quality Assessment**: Check code standards, testing, and documentation
4. **Deviation Analysis**: Identify and evaluate any plan deviations
5. **Completion Validation**: Confirm objectives were met

## Review Categories

- **Functional Review**: Does the implementation work as planned?
- **Quality Review**: Does the code meet repository standards?
- **Completeness Review**: Were all planned steps implemented?
- **Deviation Review**: Are any deviations acceptable and documented?

## Review Checklist

- [ ] All planned steps were implemented
- [ ] Implementation matches plan specifications
- [ ] Code follows repository standards
- [ ] Project-specific quality criteria are satisfied (see `code-quality-standards.mdc`)
- [ ] Validation passes for affected components
- [ ] Documentation is updated
- [ ] No unintended side effects introduced
- [ ] Deviations are documented and justified

## Deviation Types

- **Acceptable Deviations**: Improvements or optimizations that maintain plan intent
- **Required Deviations**: Changes needed due to unforeseen technical constraints
- **Problematic Deviations**: Changes that may compromise the plan's objectives

## Review Outputs

- **Compliance Report**: How well implementation matches the plan
- **Quality Assessment**: Code standards and best practices evaluation
- **Deviation Summary**: Any differences from plan with rationale
- **Completion Status**: What was accomplished vs. what was planned
- **Recommendations**: Suggestions for improvements or next steps

## Quality Verification

Refer to your project's `code-quality-standards.mdc` for quality checks and `development-commands.mdc` for verification commands.

## Next Step

Review is the end of the RIPER chain. After review completion:
- If review passes, work is complete
- If issues found, return to plan or execute as needed

No auto-chaining — the user decides what to do next.

## Integration

- **Standalone**: Used outside of execute workflows
- **References**: `code-quality-standards.mdc`, `development-commands.mdc`
- **Related**: `reviewing-implementation` skill (used within execute workflows)
