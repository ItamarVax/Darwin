# Defense in Depth

Add validation at multiple layers after finding and fixing a root cause.

## When to Use

After completing Phase 4 of systematic debugging, use this technique to prevent the same class of bug from recurring. This is NOT about fixing the current bug — that's already done. This is about hardening the system.

## The Technique

### Identify the Failure Path

Map out every layer the bad data passed through before causing the symptom:

```
input → Layer 1 (entry point) → Layer 2 (processing) → Layer 3 (output) → symptom
```

### Add Validation at Each Layer

For each layer the bad data passed through unchallenged, consider adding a check:

| Layer | Validation Type | Example |
|-------|----------------|---------|
| Entry point | Input validation | Reject None/empty values early |
| Processing | Precondition assertions | `assert model_id is not None` |
| Output | Result validation | Verify output shape before returning |
| Boundaries | Contract checks | Validate data crossing module boundaries |

### Prioritize by Impact

Not every layer needs validation. Prioritize:

1. **Module boundaries** — where data crosses from one module to another
2. **External inputs** — user input, API responses, file contents, env vars
3. **Expensive operations** — validate before making an LLM call, not after

### Keep It Proportional

- A config field that was missing a default → add the default + a startup validation
- A function that received None → add a type hint + an early return or raise
- A multi-step pipeline that silently corrupted data → add boundary checks between steps

Don't add validation everywhere — add it where the cost of failure is high and the check is cheap.

## Anti-Patterns

| Anti-pattern | Why it's wrong |
|---|---|
| Validating everything everywhere | Noise hides real issues |
| Only validating at the symptom point | Doesn't prevent new paths to the same bug |
| Silent fallbacks (`or default_value`) | Masks bugs instead of surfacing them |
| Validation without clear error messages | Makes the next debugging session harder |
