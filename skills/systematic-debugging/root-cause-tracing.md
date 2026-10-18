# Root Cause Tracing

Trace bugs backward through the call stack to find the original trigger.

## When to Use

Use this technique in Phase 1 of systematic debugging when:
- The error is deep in the call stack
- The symptom is far from the cause
- You see a bad value but don't know where it originated

## The Technique

### Step 1: Start at the Symptom

Identify the exact point where the bad behavior is observed:
- The line that throws the error
- The variable that has the wrong value
- The function that returns unexpected output

### Step 2: Trace Backward

From the symptom, ask: "Where did this bad value come from?"

- If it's a function parameter → who called this function with this value?
- If it's a computed value → which input to the computation was wrong?
- If it's a stored value → when and where was it stored?

### Step 3: Repeat Until Source

Keep tracing backward through the call chain:

```
symptom → called by → called by → called by → ROOT CAUSE
```

At each step:
- Read the actual code (don't guess from function names)
- Check the actual values (add logging/prints if needed)
- Verify your assumptions about what each function does

### Step 4: Verify the Root

You've found the root cause when:
- You can explain WHY the bad value was produced
- Fixing this point would prevent the symptom
- The fix doesn't require changing code downstream of this point

## Common Mistakes

| Mistake | Why it's wrong | Do this instead |
|---------|---------------|-----------------|
| Fixing at the symptom | Masks the real problem | Trace to the source |
| Stopping too early | Fix will be fragile | Keep tracing until you find the WHY |
| Guessing the call chain | May trace the wrong path | Read the actual code |
| Ignoring intermediate transforms | Data may be corrupted in transit | Check values at every hop |

## Example

```
Error: "Connection refused: host=None"
  ↑ connect_to_service() received host=None
  ↑ called by process_request() which passed config.service_host
  ↑ config.service_host is None because defaults weren't initialized
  ↑ ROOT CAUSE: missing env var and no fallback default
  → Fix: add default value to config.service_host field
```
