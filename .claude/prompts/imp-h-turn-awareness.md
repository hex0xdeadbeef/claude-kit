# IMP-H: Turn Awareness & Output Protection

## Summary
Calibrate agent RULE_5 thresholds and add SubagentStop verdict protection to reduce INCOMPLETE_OUTPUT events.

## Complexity
S (agent definition updates + hook enhancement)

## Scope

### Part 1: Upgrade plan-reviewer RULE_5 to 3-tier structure
**File:** `.claude/agents/plan-reviewer.md`

Current: single "28+ tool calls → skip to verdict" heuristic.
Proposed: 3-tier structure matching code-reviewer (proportional to maxTurns=40):
- TIER 1 (turn 20): Self-check — "Have I started review sections yet?"
- TIER 2 (turn 28): Hard abort — output verdict immediately
- TIER 3 (turn 35, 5 remaining): Memory deadline

Also add note about IMP-A SubagentStart context injection reducing turn 1-3 overhead.

### Part 2: Update code-reviewer RULE_5 with IMP-A note
**File:** `.claude/agents/code-reviewer.md`

Add note to RULE_5 about IMP-A context injection. Current thresholds (25/33/40 of 45) are well-calibrated — no change needed.

### Part 3: Add SubagentStop verdict protection
**File:** `.claude/scripts/save-review-checkpoint.sh`

When verdict extraction fails (verdict == "UNKNOWN"):
1. Check if this agent_id has been blocked before (file: `.claude/workflow-state/.verdict-block-{agent_id}`)
2. If first attempt → write block marker file, output `{"decision": "block", "reason": "No verdict found in output. Output VERDICT: {APPROVED|NEEDS_CHANGES|CHANGES_REQUESTED|REJECTED} followed by handoff now."}`
3. If second attempt (marker exists) → allow stop, write UNKNOWN verdict to review-completions.jsonl, clean up marker file
4. Skip blocking for non-review agents (agent_type not in plan-reviewer, code-reviewer)

## Architecture Decisions
- Block marker uses agent_id (unique per launch) — no cross-agent interference
- Marker files cleaned up inline (step 3) — no separate cleanup needed
- Only review agents get blocking — other agents stop normally
- Block message includes expected output format to guide the agent

## Risk Assessment
- MEDIUM risk on Part 3: blocking agent may waste turns if truly stuck
- Mitigation: max 1 block per agent launch (marker-based tracking)
- Parts 1-2 are LOW risk (documentation/threshold changes)

## Files Modified
1. EDIT: `.claude/agents/plan-reviewer.md` (Part 1)
2. EDIT: `.claude/agents/code-reviewer.md` (Part 2)
3. EDIT: `.claude/scripts/save-review-checkpoint.sh` (Part 3 — user applies)
