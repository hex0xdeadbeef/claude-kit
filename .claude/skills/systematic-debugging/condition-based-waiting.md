# Condition-Based Waiting

## Overview

Flaky tests often guess at timing with arbitrary delays (`time.Sleep`). This creates
race conditions where tests pass on fast machines but fail under load or in CI.

**Core principle:** Wait for the actual condition you care about, not a guess about
how long it takes.

## When to Use

**Use when:**
- Tests have arbitrary delays (`time.Sleep` with magic numbers)
- Tests are flaky (pass sometimes, fail under load or in CI)
- Tests timeout when run in parallel (`go test -parallel N`)
- Waiting for async operations, goroutines, or channel messages to complete

**Don't use when:**
- Testing actual timing behavior (debounce intervals, rate limiting)
- Always document WHY if using arbitrary sleep

## Core Pattern

```go
// ❌ BEFORE: Guessing at timing
time.Sleep(50 * time.Millisecond)
result := getResult()
assert.NotNil(t, result)

// ✅ AFTER: Condition-based (testify/require.Eventually)
require.Eventually(t, func() bool {
    return getResult() != nil
}, 5*time.Second, 10*time.Millisecond)
result := getResult()
assert.NotNil(t, result)
```

## Quick Patterns

| Scenario | Pattern |
|----------|---------|
| Wait for goroutine result | `require.Eventually(t, func() bool { return result != nil }, 5*time.Second, 10*time.Millisecond)` |
| Wait for channel message | `select { case msg := <-ch: ...; case <-time.After(5*time.Second): t.Fatal("timeout") }` |
| Wait for count | `require.Eventually(t, func() bool { return len(items) >= 5 }, 5*time.Second, 10*time.Millisecond)` |
| Wait for file | `require.Eventually(t, func() bool { _, err := os.Stat(path); return err == nil }, 5*time.Second, 10*time.Millisecond)` |
| Complex condition | `require.Eventually(t, func() bool { return obj.Ready && obj.Value > 10 }, 5*time.Second, 10*time.Millisecond)` |

## Primary Implementation (testify)

```go
import "github.com/stretchr/testify/require"

// require.Eventually(t, condition, waitFor, tick, msgAndArgs...)
require.Eventually(t,
    func() bool { return processor.Done() },
    5*time.Second,       // total timeout
    10*time.Millisecond, // polling interval
    "processor did not complete within 5s",
)
```

## Fallback Implementation (without testify)

```go
func waitFor(t *testing.T, condition func() bool, description string, timeout time.Duration) {
    t.Helper()
    deadline := time.Now().Add(timeout)
    for time.Now().Before(deadline) {
        if condition() {
            return
        }
        time.Sleep(10 * time.Millisecond) // poll every 10ms
    }
    t.Fatalf("timeout waiting for %s after %v", description, timeout)
}

// Usage
waitFor(t, func() bool { return getResult() != nil }, "result to be non-nil", 5*time.Second)
```

## Channel-Based Waiting

For event-driven systems (channels are the condition):

```go
// ✅ Wait for specific channel message
select {
case msg := <-eventCh:
    assert.Equal(t, "DONE", msg.Type)
case <-time.After(5 * time.Second):
    t.Fatal("timeout waiting for DONE event")
}

// ✅ Wait for goroutine to complete
done := make(chan struct{})
go func() {
    defer close(done)
    // do work
}()
select {
case <-done:
    // success
case <-time.After(5 * time.Second):
    t.Fatal("goroutine did not complete within 5s")
}
```

## Common Mistakes

**❌ Polling too fast:**
```go
time.Sleep(time.Millisecond) // 1ms — wastes CPU
```
**✅ Fix:** Poll every 10ms (default in `require.Eventually`)

**❌ No timeout:**
```go
for { if done() { break } } // hangs if condition never met
```
**✅ Fix:** Always include timeout with clear error message

**❌ Stale data (cached value before loop):**
```go
result := getResult() // evaluated once before polling
require.Eventually(t, func() bool { return result != nil }, ...)
```
**✅ Fix:** Call getter inside condition function for fresh data:
```go
require.Eventually(t, func() bool { return getResult() != nil }, ...)
```

**❌ Race condition — reading shared state without synchronization:**
```go
require.Eventually(t, func() bool { return shared.Done }, ...) // data race
```
**✅ Fix:** Use atomic or mutex:
```go
var done atomic.Bool
require.Eventually(t, func() bool { return done.Load() }, ...)
```

## When Arbitrary Sleep IS Correct

```go
// Worker ticks every 100ms — need 2 ticks to verify partial output
waitForEvent(t, "WORKER_STARTED") // First: wait for condition
time.Sleep(250 * time.Millisecond) // Then: wait for timed behavior
// 250ms = 2+ ticks at 100ms intervals — documented and justified
```

**Requirements:**
1. First wait for triggering condition
2. Based on known timing (not guessing)
3. Comment explaining WHY with the timing rationale

## Real-World Impact

Condition-based waiting eliminates an entire class of flaky tests:
- Race detector (`go test -race`) won't flag condition-based waits
- Tests pass under load and in CI (no timing assumptions)
- Faster overall: no over-sleeping on fast machines
