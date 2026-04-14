---
name: imp-5-verify-subagent-start-worktree
complexity: S
type: diagnostic
status: approved
created: 2026-04-14
platform_version: v2.1.105
priority: medium
---

# IMP-5: Verify SubagentStart firing for worktree-isolated agents

## Goal

Instrument `track-task-lifecycle.sh` with a **positive probe** that writes to
`.claude/workflow-state/anomalies.jsonl` whenever `SubagentStart` fires for
`code-reviewer` with a properly-resolved `agent_type`. Together with the existing
P2-2 negative probe in `save-review-checkpoint.sh`, this gives orchestrator a
single authoritative file (anomalies.jsonl) with dual-signal evidence to decide
whether the P0-2 worktree heuristic can be removed.

**Scope: diagnostic-only.** No P0-2 removal, no settings.json changes, no
behavior changes. Pure observability improvement.

## Current state (empirical, not theoretical)

Evidence from the current session's hook logs:

| File | Line | Hook | agent_id | agent_type | Conclusion |
|------|------|------|----------|------------|------------|
| worktree-events-debug.jsonl | 1 | SubagentStop | a6fceb6836a496303 | `""` (empty) + agent_transcript_path present | worktree code-reviewer — P0-2 heuristic recovered |
| worktree-events-debug.jsonl | 2 | SubagentStart | acac8b58c14227d4e | `"plan-reviewer"` | plan-reviewer fires correctly (no worktree) |
| worktree-events-debug.jsonl | 3 | SubagentStop | acac8b58c14227d4e | `"plan-reviewer"` | plan-reviewer pair intact |
| worktree-events-debug.jsonl | 4 | SubagentStop | a03b7664b2443e656 | `""` (empty) + agent_transcript_path present | second worktree code-reviewer — P0-2 heuristic recovered |
| task-events.jsonl | 1 | SubagentStart | acac8b58c14227d4e | `"plan-reviewer"` | the only SubagentStart in the file |

Direct conclusion: **in v2.1.105, SubagentStart does not fire for `isolation:worktree`
subagents, and SubagentStop delivers `agent_type: ""` for them.** The P0-2
heuristic (presence of `agent_transcript_path`) is what keeps the pipeline working.

anomalies.jsonl does not exist yet. The P2-2 probe in
`save-review-checkpoint.sh:142-156` will create it the next time a worktree
code-reviewer runs. Adding a positive probe now ensures the file has **both**
signals from the moment it is first created.

## Why a positive probe (not just "rely on negative")

The P2-2 probe tells us "SubagentStart didn't fire" by inference (empty agent_type
+ transcript path on SubagentStop). It cannot tell us "SubagentStart fired
correctly" because SubagentStop is a separate hook.

Without a positive signal:
- Absence of `MISSING_SUBAGENT_START` entries could mean either (a) platform fixed,
  or (b) no code-reviewer ran recently. Ambiguous.
- No clean criterion for removing P0-2 in a follow-up IMP.

With a positive probe:
- `SUBAGENT_START_FIRED` entry for code-reviewer = platform sends the hook AND
  the payload is correct → P0-2 is obsolete.
- 0 `SUBAGENT_START_FIRED` + ≥1 `MISSING_SUBAGENT_START` over a window → P0-2 still
  load-bearing.
- Decision gate has a simple, falsifiable criterion.

## Proposal review

| Original claim | Reality |
|----------------|---------|
| "Add debug subagent in SubagentStart hooks for explicit verification" | Not needed — we already have `track-task-lifecycle.sh` registered on SubagentStart for code-reviewer (settings.json:252-263). The script just needs one extra block. |
| "Write to anomalies.jsonl when agent_type is resolved correctly for code-reviewer" | ✅ Adopted verbatim. Uses `SUBAGENT_START_FIRED` as symmetric discriminator to P2-2's `MISSING_SUBAGENT_START`. |
| "Remove P0-2 heuristic after verification" | ⛔ Out of scope for IMP-5. Requires evidence collection first. Will propose as follow-up IMP once anomalies.jsonl accumulates data across ≥3 `/workflow` runs. |

## Affected files

| File | Change | Protected? |
|------|--------|------------|
| `.claude/scripts/track-task-lifecycle.sh` | Append ~15-line Python block after existing `worktree-events-debug.jsonl` write (line 72) | **Yes** — `.claude/scripts/**` protected by `protect-files.sh` |

## Out of scope

- No changes to `.claude/settings.json` (SubagentStart hook registration unchanged).
- No changes to `save-review-checkpoint.sh` P0-2 heuristic or P2-2 negative probe.
- No changes to `inject-review-context.sh` (runs on same SubagentStart event for code-reviewer; unrelated logic).
- No removal or guarding of worktree-events-debug.jsonl (will be re-evaluated in follow-up IMP once diagnostic data is sufficient).
- No update to CLAUDE.md / docs — diagnostic infrastructure, not user-visible.

## Design

### What to log

When SubagentStart fires and `agent_type == "code-reviewer"` (i.e., the platform
did deliver the hook and the payload correctly) AND `agent_id` is non-empty,
append one line to anomalies.jsonl:

```json
{
  "timestamp": "2026-04-14T23:45:00Z",
  "type": "SUBAGENT_START_FIRED",
  "agent_id": "a03b7664b2443e656",
  "agent_type": "code-reviewer",
  "session_id": "...",
  "message": "SubagentStart fired for code-reviewer — P0-2 worktree heuristic may be obsolete"
}
```

### Symmetry with P2-2

| Probe | File (writer) | Line range | Trigger | `type` field |
|-------|--------------|------------|---------|--------------|
| Positive (IMP-5, new) | track-task-lifecycle.sh | ~end of PYTHON_EOF | SubagentStart agent_type == code-reviewer | `SUBAGENT_START_FIRED` |
| Negative (P2-2, existing) | save-review-checkpoint.sh | 142-156 | SubagentStop agent_type mismatch + no registry | `MISSING_SUBAGENT_START` |

Both write to the same `anomalies.jsonl` file with a discriminator `type` field, so
one read is enough to answer "what happened during this code-reviewer run?"

### Scope to code-reviewer only

plan-reviewer already fires SubagentStart correctly (evidence above). Adding a
positive probe for plan-reviewer would spam anomalies.jsonl with "working as
expected" entries — anomaly files should log *surprising* events, not baseline.

If a future platform regression breaks plan-reviewer's SubagentStart, the existing
registry-miss path in P2-2 would catch it via a different signal (registry lookup
failure). No action needed here.

### Exact code to add

Insert after line 72 (the `except Exception: pass` of the IMP-18 debug block)
and before the closing `PYTHON_EOF` at line 73:

```python

# IMP-5: Positive probe — log when SubagentStart fires for code-reviewer with
# correctly-resolved agent_type. Pairs with P2-2 negative probe in
# save-review-checkpoint.sh (MISSING_SUBAGENT_START).
# Decision gate: if anomalies.jsonl accumulates SUBAGENT_START_FIRED entries for
# code-reviewer across multiple /workflow runs AND zero MISSING_SUBAGENT_START,
# the P0-2 worktree heuristic can be removed. Until then, P0-2 stays.
if entry["agent_type"] == "code-reviewer" and entry["agent_id"]:
    try:
        anomaly = {
            "timestamp": entry["timestamp"],
            "type": "SUBAGENT_START_FIRED",
            "agent_id": entry["agent_id"],
            "agent_type": "code-reviewer",
            "session_id": entry["session_id"],
            "message": "SubagentStart fired for code-reviewer — P0-2 worktree heuristic may be obsolete",
        }
        with open(os.path.join(STATE_DIR, "anomalies.jsonl"), "a") as f:
            f.write(json.dumps(anomaly) + "\n")
    except Exception:
        pass  # NON_CRITICAL — diagnostic only
```

No other changes to `track-task-lifecycle.sh`. The existing `task-events.jsonl`,
`agent-id-registry.jsonl`, and `worktree-events-debug.jsonl` writes remain intact.

## Decision gate (when to remove P0-2)

After this change lands, the criterion for a follow-up "remove P0-2 heuristic"
IMP is:

1. At least **3 distinct /workflow runs** have completed with code-reviewer (to
   sample across sessions, not just one).
2. Inspect `anomalies.jsonl`:
   - **≥1 `SUBAGENT_START_FIRED` entry per code-reviewer run AND 0
     `MISSING_SUBAGENT_START` entries** → platform is correct, P0-2 obsolete,
     propose removal.
   - **0 `SUBAGENT_START_FIRED` + ≥1 `MISSING_SUBAGENT_START` per run** →
     platform still doesn't fire SubagentStart for worktree agents, P0-2 stays.
   - **Mixed (some of each)** → intermittent platform behavior; keep P0-2, file a
     platform issue.
3. Sample can be taken any time with:
   ```bash
   # Extract just the `type` discriminator so sort|uniq -c actually collapses duplicates.
   # The positive probe (IMP-5) writes agent_type="code-reviewer"; the negative probe (P2-2)
   # writes effective_agent_type="code-reviewer" + raw_agent_type="unknown" — so the `or`
   # correctly covers both shapes.
   jq -r 'select(.effective_agent_type == "code-reviewer" or .agent_type == "code-reviewer") | .type' \
     .claude/workflow-state/anomalies.jsonl | sort | uniq -c
   ```
   Expected output shape (one line per distinct `type`):
   ```
      3 MISSING_SUBAGENT_START    # P0-2 still needed
      3 SUBAGENT_START_FIRED      # P0-2 candidate for removal
   ```

## Verification

All smoke tests assume cwd = repo root (matches how Claude Code invokes the hook).
Prefix every block below with the cd line or run them in a shell already at the repo root.

### Syntax
```bash
cd "$(git rev-parse --show-toplevel)"
bash -n .claude/scripts/track-task-lifecycle.sh && echo "bash OK"
```

### Smoke test 1 — SubagentStart for code-reviewer (positive case)

Simulate the payload the platform would send IF it fired SubagentStart for a
worktree code-reviewer. This tests the happy path.

```bash
cd "$(git rev-parse --show-toplevel)"

# Preflight — snapshot anomalies.jsonl state (may not exist)
BEFORE=$(wc -l < .claude/workflow-state/anomalies.jsonl 2>/dev/null || echo 0)

# Feed synthetic SubagentStart payload
echo '{
  "hook_event_name": "SubagentStart",
  "agent_type": "code-reviewer",
  "agent_id": "test-smoke-1-code-reviewer",
  "session_id": "smoke-test-session"
}' | bash .claude/scripts/track-task-lifecycle.sh

# Verify anomalies.jsonl received the positive probe
AFTER=$(wc -l < .claude/workflow-state/anomalies.jsonl)
echo "Lines: before=$BEFORE after=$AFTER (expected: +1)"
tail -1 .claude/workflow-state/anomalies.jsonl | python3 -m json.tool
```

Expected:
- `AFTER - BEFORE == 1`
- Last entry has `"type": "SUBAGENT_START_FIRED"`, `"agent_type": "code-reviewer"`, `"agent_id": "test-smoke-1-code-reviewer"`.

Cleanup:
```bash
# Remove the synthetic entry (last line)
sed -i '' -e '$d' .claude/workflow-state/anomalies.jsonl
# If file is now empty, remove it so the next real run creates a clean file
[ ! -s .claude/workflow-state/anomalies.jsonl ] && rm .claude/workflow-state/anomalies.jsonl
```

### Smoke test 2 — SubagentStart for plan-reviewer (negative case — should NOT log)

Ensures we don't spam anomalies.jsonl with non-code-reviewer events.

```bash
cd "$(git rev-parse --show-toplevel)"
BEFORE=$(wc -l < .claude/workflow-state/anomalies.jsonl 2>/dev/null || echo 0)

echo '{
  "hook_event_name": "SubagentStart",
  "agent_type": "plan-reviewer",
  "agent_id": "test-smoke-2-plan-reviewer",
  "session_id": "smoke-test-session"
}' | bash .claude/scripts/track-task-lifecycle.sh

AFTER=$(wc -l < .claude/workflow-state/anomalies.jsonl 2>/dev/null || echo 0)
echo "Lines: before=$BEFORE after=$AFTER (expected: no change, delta=0)"
```

Expected: `AFTER == BEFORE` (no write for plan-reviewer).

### Smoke test 3 — SubagentStart with empty agent_type (edge case — should NOT log)

If the platform starts delivering SubagentStart for worktree agents but with
empty agent_type (same bug as SubagentStop has today), we do NOT want to log a
false "P0-2 may be obsolete" signal.

```bash
cd "$(git rev-parse --show-toplevel)"
BEFORE=$(wc -l < .claude/workflow-state/anomalies.jsonl 2>/dev/null || echo 0)

echo '{
  "hook_event_name": "SubagentStart",
  "agent_type": "",
  "agent_id": "test-smoke-3-empty-type",
  "session_id": "smoke-test-session"
}' | bash .claude/scripts/track-task-lifecycle.sh

AFTER=$(wc -l < .claude/workflow-state/anomalies.jsonl 2>/dev/null || echo 0)
echo "Lines: before=$BEFORE after=$AFTER (expected: no change, delta=0)"
```

Expected: `AFTER == BEFORE` (the `entry["agent_type"] == "code-reviewer"` guard rejects empty string).

### Smoke test 4 — task-events.jsonl and agent-id-registry.jsonl still work

Ensure the new block didn't break existing functionality.

```bash
cd "$(git rev-parse --show-toplevel)"
# The test 1 payload above should have written to task-events.jsonl AND agent-id-registry.jsonl.
tail -1 .claude/workflow-state/task-events.jsonl | python3 -m json.tool
tail -1 .claude/workflow-state/agent-id-registry.jsonl | python3 -m json.tool
```

Expected: both files have entries for `test-smoke-1-code-reviewer` with `agent_type: "code-reviewer"`.

Cleanup test-synthetic lines:
```bash
# Remove the tail entries from smoke tests (approximate — only do if you're sure the last entries are test-generated)
# Simpler: sed -i '' -e '$d' on each file.
```

### Real integration (manual, optional)

1. Run a real `/workflow` on any small task that reaches Phase 4 (code-reviewer).
2. After code-reviewer completes, inspect:
   ```bash
   cat .claude/workflow-state/anomalies.jsonl | jq -c 'select(.agent_id | startswith("a"))'
   ```
3. Expected current platform behavior (v2.1.105): 1 `MISSING_SUBAGENT_START` entry, 0 `SUBAGENT_START_FIRED` entries. This confirms the probe works and P0-2 is still needed.
4. If you see `SUBAGENT_START_FIRED` for code-reviewer: great news — kick off the follow-up "remove P0-2" IMP.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Positive-probe block throws and fails `task-events.jsonl` write | LOW | MEDIUM | New code inside its own `try/except`; `set -uo pipefail` (not `-e`); outer `2>/dev/null \|\| true` on python3 block; existing `task-events.jsonl` write runs BEFORE the new block |
| anomalies.jsonl grows unbounded | LOW | LOW | Only fires on code-reviewer SubagentStart (currently 0 times/session; even if platform fixes, ≤1/workflow run). |
| False positive if plan-reviewer briefly has agent_type mismatch | LOW | LOW | Explicit `== "code-reviewer"` guard rejects all other types. |
| Smoke test cleanup with `sed -i '' -e '$d'` on macOS vs Linux divergence | LOW | LOW | All verification runs on macOS (user's platform per environment info). Clean-up is manual and reviewable. |
| Decision gate threshold ("3 runs") too aggressive/loose | LOW | LOW | Threshold is advisory. Follow-up IMP will re-read evidence and justify the call. |

## Performance

- One extra dict construction + one conditional file append, gated on `agent_type == "code-reviewer"`.
- Fires at most once per SubagentStart hook (which fires ≤N times per `/workflow`, where N = review iterations).
- No subprocess, no network, no disk scan. ~1ms added work when gate matches, ~0 when it doesn't.

## Handoff for user

**Single manual step** (protected file):

### Apply the patch

Open `.claude/scripts/track-task-lifecycle.sh`. Insert the "Exact code to add"
block between the end of the IMP-18 debug block (last statement: `pass` at the
bottom of that `try/except`) and the closing heredoc marker `PYTHON_EOF`.

**Location anchor (verbatim — grep-matchable).** Before applying, confirm these
exact four lines still appear consecutively near the end of the script. If they
don't (e.g., because another IMP reshaped the IMP-18 block), re-verify the anchor
before editing:

```python
    with open(DEBUG_FILE, "a") as f:
        f.write(json.dumps(debug_entry) + "\n")
except Exception:
    pass
```

Insertion point: **immediately after the `    pass` line above, and immediately
before the `PYTHON_EOF` heredoc terminator.** The insert adds one blank line
plus the "Exact code to add" block, preserving the `PYTHON_EOF` terminator
untouched on its own line.

Quick pre-apply anchor check:
```bash
cd "$(git rev-parse --show-toplevel)"
grep -n -A3 'with open(DEBUG_FILE, "a") as f:' .claude/scripts/track-task-lifecycle.sh
# Expect to see the 4-line anchor above. If grep returns nothing or something else,
# STOP — the IMP-18 block has shifted and this plan needs an update before applying.
```

At the time this plan was written, the anchor appears at lines 69–72 of
`track-task-lifecycle.sh` with `PYTHON_EOF` on line 73.

### Post-apply verification the agent will run

1. `bash -n .claude/scripts/track-task-lifecycle.sh` → syntax OK
2. Smoke test 1 (code-reviewer payload) → `SUBAGENT_START_FIRED` line appended to anomalies.jsonl
3. Smoke test 2 (plan-reviewer payload) → no new line in anomalies.jsonl
4. Smoke test 3 (empty agent_type) → no new line in anomalies.jsonl
5. Smoke test 4 (task-events.jsonl + agent-id-registry.jsonl) → existing writes intact
6. Cleanup any synthetic lines left by smoke tests

### Plan-review revisions (iteration 1/3 → APPROVED, 3 MINOR applied)

Applied per plan-reviewer agent verdict:

- **PR-001 (MINOR — completeness):** "Location anchor" in handoff rewritten from an
  ellipsis-based snippet to a verbatim 4-line grep-matchable anchor, plus a
  pre-apply `grep -n -A3` check. Reason: if a prior IMP shifts the IMP-18 block,
  line number 72 becomes wrong — textual anchor with `...` wouldn't grep cleanly.
- **PR-002 (MINOR — completeness):** Decision-gate jq one-liner fixed. Was piping
  full JSON lines through `sort | uniq -c` (never collapses due to unique
  `timestamp`/`agent_id`). Now extracts `.type` field only, which is the actual
  signal the gate needs. Added expected-output shape for clarity.
- **PR-003 (MINOR — completeness):** All four smoke-test blocks now prefixed with
  `cd "$(git rev-parse --show-toplevel)"`. Reason: script uses relative
  `STATE_DIR=".claude/workflow-state"` (line 11); a smoke run from a sibling
  directory would silently create a phantom state dir.

No design changes; scope unchanged; Python block for `track-task-lifecycle.sh` is
identical to the plan-reviewer-approved version.

### Commit message

```
feat(hooks): IMP-5 positive SubagentStart probe for worktree verification

Adds SUBAGENT_START_FIRED entries to anomalies.jsonl when code-reviewer's
SubagentStart hook delivers a correctly-resolved agent_type. Pairs with the
existing P2-2 MISSING_SUBAGENT_START probe in save-review-checkpoint.sh to
provide dual-signal evidence for a future decision on removing the P0-2
worktree heuristic. Diagnostic-only: no behavior change.
```
