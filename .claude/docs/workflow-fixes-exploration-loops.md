# Workflow Fixes: Exploration Loops

**Date:** 2026-03-20
**Based on:** `workflow-research-report.md`
**Problem:** Claude gets stuck in exploration loops (25 friction events) — reads files endlessly without transitioning to action
**Root Cause:** Inter-phase governance exists (loop limits, handoffs), but intra-phase governance is absent (no exploration budgets, no transition signals)

---

## Fix Overview

| Fix | Target Issue(s) | Artifacts Modified | Severity | Risk |
|-----|-----------------|-------------------|----------|------|
| FIX-01 | ISSUE-01, ISSUE-04 | CLAUDE.md, autonomy.md | CRITICAL | Low |
| FIX-02 | ISSUE-02, ISSUE-07 | planner.md, planner-rules/task-analysis.md | CRITICAL | Medium |
| FIX-03 | ISSUE-03, ISSUE-07 | coder.md, coder-rules/SKILL.md | HIGH | Medium |
| FIX-04 | ISSUE-06 | planner.md, coder.md | MEDIUM | Low |
| FIX-05 | ISSUE-08 | planner.md, coder.md, planner-rules/checklist.md, coder-rules/checklist.md | MEDIUM | Low |
| FIX-06 | ISSUE-05 | enrich-context.sh, checkpoint-protocol.md | MEDIUM | Medium |
| FIX-07 | ISSUE-09 | session-analytics.sh, pipeline-metrics.md | LOW | Low |
| FIX-08 | ISSUE-10 | CLAUDE.md | LOW | Low |

---

## FIX-01: Add EXPLORATION_THRESHOLD to Error Handling and Autonomy

### Target
- ISSUE-01: No exploration loop detection
- ISSUE-04: Missing exploration budget in autonomy stop conditions

### Changes

**File: `CLAUDE.md` — Error Handling table**

Add new row:

```markdown
| Exploration loop (Read/Grep >N budget) | STOP_AND_TRANSITION | Show files read, summarize findings, transition to next sub-phase |
```

**File: `.claude/skills/workflow-protocols/autonomy.md` — Stop conditions table**

Add new row:

```markdown
| EXPLORATION_THRESHOLD (file reads exceed budget for complexity) | Summarize findings so far, transition to next sub-phase (DESIGN/IMPLEMENT) |
```

Add new continue condition:

```markdown
| Exploration within budget | Continue research |
```

### Rationale
This establishes the vocabulary and top-level enforcement. Individual budgets are defined in FIX-02 and FIX-03. The key design choice is **STOP_AND_TRANSITION** (not STOP_AND_WAIT) — Claude should summarize what it found and move forward, not stop and ask the user. Exploration loops happen because Claude wants "complete" research before acting; the fix is to force action with incomplete information.

### Self-Review

| Check | Status | Notes |
|-------|--------|-------|
| Backwards compatible | PASS | New rows don't break existing behavior |
| Consistent terminology | PASS | Uses same pattern as FAILURE_THRESHOLD |
| Not over-engineering | PASS | Minimal addition — 2 rows total |
| Addresses root cause | PARTIAL | Establishes vocabulary; actual budgets in FIX-02/03 |
| Impact on project-researcher | NEUTRAL | PR has own stop conditions; this adds shared vocabulary |
| Risk assessment | LOW | Adding to tables is non-breaking |

**Verdict:** APPROVED — minimal, non-breaking addition that establishes necessary vocabulary.

---

## FIX-02: Add Graduated Exploration Budget to Planner

### Target
- ISSUE-02: Planner research phase has no budget
- ISSUE-07: No graduated budget by complexity

### Changes

**File: `planner.md` — Phase 3 (RESEARCH) section**

Add exploration budget block after the research strategy section:

```yaml
research_budget:
  purpose: "Prevent exploration loops. When budget exceeded → STOP_AND_TRANSITION to DESIGN with findings so far."
  budgets:
    S:
      file_reads: 5
      tool_calls: 12
      signal: "Pattern already exists in project. Find one example and proceed."
    M:
      file_reads: 10
      tool_calls: 20
      signal: "After 10 file reads, summarize findings and transition to DESIGN."
    L:
      file_reads: 20
      tool_calls: 35
      delegate: "After 8 direct reads, delegate remaining to code-researcher."
      signal: "After 20 reads total, summarize and transition."
    XL:
      file_reads: 30
      tool_calls: 50
      delegate: "MANDATORY code-researcher for multi-package research."
      signal: "After 30 reads total, summarize and transition."
  on_exceeded: |
    1. STOP reading new files
    2. Summarize what you found (patterns, files, gaps)
    3. Note what remains unknown
    4. Transition to DESIGN phase with available information
    5. Mark unknown areas as "NEEDS_VALIDATION" in plan
  tracking: "Count file reads (Read + Grep + Glob results opened) against budget"
```

**File: `.claude/skills/planner-rules/task-analysis.md` — Complexity routing matrix**

Add budget column to the routing table:

```yaml
Complexity | Parts | Layers | Route        | ST           | Plan Review | Research Budget
S          | 1     | 1      | minimal      | NOT needed   | SKIP        | 5 reads / 12 calls
M          | 2-3   | 2      | standard     | as needed    | standard    | 10 reads / 20 calls
L          | 4-6   | 3+     | standard     | RECOMMENDED  | standard    | 20 reads / 35 calls
XL         | 7+    | 4+     | full         | REQUIRED     | standard    | 30 reads / 50 calls
```

### Rationale
The budget numbers are based on the observation that code-researcher (which works well) has maxTurns=20. For S/M tasks where planner researches directly, the budget should be comparable. The key innovation is the **delegate trigger** for L tasks: after 8 direct reads, remaining research should be delegated to code-researcher, which has its own bounded context.

The **NEEDS_VALIDATION** marker for unknown areas is critical — it allows the plan to proceed with gaps that the coder's EVALUATE phase can catch, rather than blocking on incomplete research.

### Self-Review

| Check | Status | Notes |
|-------|--------|-------|
| Backwards compatible | PASS | Budget is additive guidance, not breaking change |
| Consistent terminology | PASS | Uses STOP_AND_TRANSITION from FIX-01 |
| Not over-engineering | REVIEW | Budget numbers are heuristic — may need tuning |
| Addresses root cause | YES | Directly limits exploration duration |
| Impact on project-researcher | POSITIVE | Establishes reusable budget pattern |
| Risk assessment | MEDIUM | Too-tight budgets could cause incomplete plans |

**Mitigation for risk:** The budgets are generous (S=5, M=10, L=20, XL=30 file reads). Most well-scoped tasks need fewer reads. If budget is hit, the NEEDS_VALIDATION marker ensures the plan still proceeds rather than failing.

**Verdict:** APPROVED with note — budget numbers should be treated as initial values subject to tuning based on real-world usage. Consider adding a feedback memory for budget adjustments.

---

## FIX-03: Add Exploration Budget to Coder Evaluate Phase

### Target
- ISSUE-03: Coder evaluate has no exploration budget
- ISSUE-07: No graduated budget by complexity

### Changes

**File: `coder.md` — Phase 1.5 (EVALUATE) section**

Add evaluate budget block:

```yaml
evaluate_budget:
  purpose: "Prevent evaluation loops. When budget exceeded → make PROCEED/REVISE/RETURN decision with available information."
  budgets:
    S:
      file_reads: 3
      tool_calls: 8
      signal: "Plan is simple. Quick feasibility check, then PROCEED."
    M:
      file_reads: 6
      tool_calls: 15
      signal: "Check key files referenced in plan. If no blockers found → PROCEED."
    L:
      file_reads: 12
      tool_calls: 25
      delegate: "After 5 direct reads, delegate gaps to code-researcher."
      signal: "After 12 reads, decide PROCEED/REVISE/RETURN."
    XL:
      file_reads: 18
      tool_calls: 35
      delegate: "MANDATORY code-researcher for gap analysis."
      signal: "After 18 reads, decide."
  on_exceeded: |
    1. STOP reading new files
    2. With available information, make decision:
       - No blockers found → PROCEED (gaps are acceptable)
       - Minor concerns → REVISE (note adjustments)
       - Major unknowns → RETURN (with specific questions for planner)
    3. Document decision rationale in evaluate output
  tracking: "Count file reads against budget"
```

**File: `.claude/skills/coder-rules/SKILL.md` — Evaluate Protocol section**

Add note after PROCEED/REVISE/RETURN definitions:

```yaml
evaluate_note: |
  Evaluate has an exploration budget (SEE coder.md → evaluate_budget).
  When budget is reached, DECIDE with available information.
  Prefer PROCEED with notes over endless research.
  The planner already researched — evaluate is VALIDATION, not discovery.
```

### Rationale
Coder evaluate budgets are tighter than planner research budgets because the planner already did research. Evaluate is meant to VALIDATE the plan, not RE-RESEARCH the codebase. The key insight is: "Prefer PROCEED with notes over endless research."

### Self-Review

| Check | Status | Notes |
|-------|--------|-------|
| Backwards compatible | PASS | Additive guidance |
| Consistent terminology | PASS | Uses same budget structure as FIX-02 |
| Not over-engineering | PASS | Tighter budgets appropriate for validation vs discovery |
| Addresses root cause | YES | Limits evaluate-phase exploration |
| Impact on project-researcher | NEUTRAL | PR doesn't have an evaluate phase |
| Risk assessment | MEDIUM | Tight budgets could cause missed issues |

**Mitigation:** The evaluate phase is followed by VERIFY (tests run). If evaluate misses something, VERIFY will catch it as test failure. The pipeline is self-correcting.

**Verdict:** APPROVED — tighter budgets are appropriate because evaluate is validation, not research. Pipeline provides safety net via VERIFY.

---

## FIX-04: Enforce Delegation Threshold for Direct Research

### Target
- ISSUE-06: Asymmetry between code-researcher budget and direct research

### Changes

**File: `planner.md` — Phase 3 (RESEARCH) section**

Modify the research strategy to lower the delegation threshold:

```yaml
research_strategy:
  simple: "1-2 files → Grep/Glob directly (within budget)"
  moderate: "3-5 files → direct research, delegate if budget 60% consumed"
  complex: "6+ files → ALWAYS delegate to code-researcher"
  override: "If S/M complexity but unfamiliar codebase → delegate to code-researcher regardless"
```

Current text says "Complex (3+ packages): Delegate to code-researcher". This changes the threshold from 3+ packages to 6+ files (lower), and adds a "moderate" tier that triggers delegation when budget is 60% consumed.

**File: `coder.md` — Phase 1.5 (EVALUATE) section**

Add similar delegation trigger:

```yaml
evaluate_delegation:
  trigger: "Budget 50% consumed without clear PROCEED/REVISE/RETURN decision"
  action: "Delegate remaining research to code-researcher with specific questions"
  skip: "S complexity (budget too small to split)"
```

### Rationale
The core issue is that S/M tasks never delegate to code-researcher because they're "too simple." But exploration loops happen most in S/M tasks precisely because there's no delegation boundary. This fix lowers the delegation threshold and adds a dynamic trigger based on budget consumption.

### Self-Review

| Check | Status | Notes |
|-------|--------|-------|
| Backwards compatible | PASS | Adds delegation triggers, doesn't remove existing paths |
| Consistent with existing patterns | PASS | code-researcher already supports this usage |
| Not over-engineering | REVIEW | "60% budget consumed" trigger adds tracking complexity |
| Addresses root cause | YES | Forces bounded context earlier |
| Risk assessment | LOW | code-researcher is well-tested and bounded |

**Verdict:** APPROVED — lowering delegation threshold is the simplest way to prevent unbounded inline research. The 60%/50% triggers are heuristic but directionally correct.

---

## FIX-05: Add Research→Action Transition Checkpoints

### Target
- ISSUE-08: No "research → action" transition checkpoint

### Changes

**File: `planner.md` — between Phase 3 and Phase 4**

Add internal transition checkpoint:

```yaml
research_to_design_gate:
  when: "After RESEARCH phase complete (or budget exceeded)"
  action: |
    Before starting DESIGN, write a brief transition summary:
    ## Research Summary
    - Files examined: {count}
    - Patterns found: {list}
    - Gaps remaining: {list or "none"}
    - Confidence: {high/medium/low}
    - Decision: Proceed to DESIGN
  purpose: "Forces explicit transition from research mode to design mode"
  enforcement: "DESIGN phase MUST NOT read new source files. Use research summary as input."
```

**File: `coder.md` — between Phase 1.5 and Phase 2**

Add internal transition checkpoint:

```yaml
evaluate_to_implement_gate:
  when: "After EVALUATE phase complete (decision made)"
  action: |
    Before starting IMPLEMENT, write evaluate output file:
    .claude/prompts/{feature}-evaluate.md (already required)
  enforcement: "IMPLEMENT phase MUST NOT re-evaluate. Trust the decision."
  additional: "If new blocker found during IMPLEMENT → mark as deviation in handoff, do NOT restart evaluate."
```

**File: `.claude/skills/planner-rules/checklist.md` — Phase 3→4 transition**

Add checklist item:

```yaml
Phase 3→4 Gate:
  - Research summary written
  - Patterns identified or gaps noted
  - Budget not exceeded (or exceeded with summary)
  - Transition to DESIGN decided
```

**File: `.claude/skills/coder-rules/checklist.md` — Evaluate→Implement transition**

Add checklist item:

```yaml
Evaluate→Implement Gate:
  - Evaluate decision made (PROCEED/REVISE/RETURN)
  - Evaluate output file written
  - If PROCEED/REVISE → transition to IMPLEMENT
  - No further research during IMPLEMENT
```

### Rationale
The transition checkpoint serves two purposes:
1. **Forces explicit mode switch** — writing a summary forces Claude to crystallize findings and move on
2. **Prevents backsliding** — the "MUST NOT read new source files" rule in DESIGN prevents returning to exploration mode

This mirrors project-researcher's pattern of state validation between subagent calls.

### Self-Review

| Check | Status | Notes |
|-------|--------|-------|
| Backwards compatible | PASS | Additive gates, no breaking changes |
| Consistent with checkpoint-protocol | PASS | Internal checkpoints complement pipeline checkpoints |
| Not over-engineering | REVIEW | "MUST NOT read new source files" is strict |
| Addresses root cause | YES | Directly prevents research→action backsliding |
| Impact on project-researcher | POSITIVE | Validates project-researcher's state validation pattern |
| Risk assessment | LOW | Gates are lightweight (summary + checklist) |

**Softening the strictness:** The "MUST NOT read new source files" rule should allow reading files **referenced in the plan being designed** (for verification). The intent is to prevent **exploratory** reads, not **targeted** reads.

**Revised rule:** "DESIGN phase MUST NOT do exploratory reads. Targeted reads of specific files referenced in the plan are allowed."

**Verdict:** APPROVED with revision — softened "no new reads" to "no exploratory reads."

---

## FIX-06: Track Sub-Phase State in Context Enrichment

### Target
- ISSUE-05: enrich-context.sh doesn't track research sub-phase state

### Changes

**File: `.claude/scripts/enrich-context.sh`**

Add sub-phase tracking by monitoring recent tool calls:

```bash
# After existing checkpoint collection, add:
# --- Sub-phase detection ---
# Count recent Read/Grep/Glob calls from session transcript
if [ -f "$WORKFLOW_STATE_DIR/session-transcript.jsonl" ]; then
  RECENT_READS=$(tail -20 "$WORKFLOW_STATE_DIR/session-transcript.jsonl" | \
    grep -c '"tool_name":"Read\|Grep\|Glob"' 2>/dev/null || echo "0")
  RECENT_WRITES=$(tail -20 "$WORKFLOW_STATE_DIR/session-transcript.jsonl" | \
    grep -c '"tool_name":"Write\|Edit"' 2>/dev/null || echo "0")

  if [ "$RECENT_READS" -gt 10 ] && [ "$RECENT_WRITES" -eq 0 ]; then
    CONTEXT="$CONTEXT\nExploration signal: $RECENT_READS reads, $RECENT_WRITES writes in last 20 calls — consider transitioning to action"
  fi
fi
```

**File: `.claude/skills/workflow-protocols/checkpoint-protocol.md`**

Add optional sub-phase fields:

```yaml
# Optional sub-phase tracking (within planner/coder)
sub_phase:
  current: "RESEARCH|DESIGN|DOCUMENT|EVALUATE|IMPLEMENT|VERIFY"
  tool_calls_in_sub_phase: N
  file_reads_in_sub_phase: N
```

### Rationale
This is a lightweight detection mechanism. It doesn't prevent exploration loops directly but makes them visible in the context, which can trigger the EXPLORATION_THRESHOLD from FIX-01.

### Self-Review

| Check | Status | Notes |
|-------|--------|-------|
| Backwards compatible | PASS | Optional additions |
| Performance impact | LOW | tail + grep on last 20 lines is fast |
| Not over-engineering | REVIEW | Depends on session-transcript.jsonl existing |
| Addresses root cause | PARTIAL | Detection, not prevention (FIX-02/03 prevent) |
| Risk assessment | MEDIUM | session-transcript.jsonl may not exist in all setups |

**Mitigation:** The detection is wrapped in `if [ -f ... ]` — graceful degradation if transcript doesn't exist.

**Verdict:** APPROVED — lightweight detection that complements prevention in FIX-02/03. May need adjustment based on actual transcript format.

---

## FIX-07: Add Exploration Metrics to Session Analytics

### Target
- ISSUE-09: session-analytics.sh doesn't track exploration metrics

### Changes

**File: `.claude/scripts/session-analytics.sh`**

Add derived metrics after existing tool_breakdown collection:

```bash
# After tool_breakdown calculation, add:
READ_COUNT=$(echo "$TOOL_BREAKDOWN" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
reads = data.get('Read', 0) + data.get('Grep', 0) + data.get('Glob', 0)
writes = data.get('Write', 0) + data.get('Edit', 0)
ratio = reads / max(writes, 1)
print(json.dumps({
    'exploration_reads': reads,
    'action_writes': writes,
    'read_write_ratio': round(ratio, 1),
    'exploration_loop_signal': ratio > 10
}))
")
```

**File: `.claude/skills/workflow-protocols/pipeline-metrics.md`**

Add anomaly detection rule:

```yaml
- read_write_ratio > 10 → Warning: "Possible exploration loop — high read/write ratio"
- exploration_reads > 30 AND action_writes == 0 → Warning: "Session appears stuck in exploration"
```

### Rationale
Post-hoc detection complements real-time prevention. If exploration loops still happen despite budgets, analytics will flag them for future budget adjustment.

### Self-Review

| Check | Status | Notes |
|-------|--------|-------|
| Backwards compatible | PASS | Adds new fields, doesn't change existing |
| Performance impact | LOW | Derived from existing data |
| Not over-engineering | PASS | Simple ratio calculation |
| Addresses root cause | NO | Post-hoc detection only |
| Risk assessment | LOW | Non-breaking addition |

**Verdict:** APPROVED — useful for iterating on budget values. Low effort, low risk.

---

## FIX-08: Unify Loop Limit Terminology

### Target
- ISSUE-10: Inconsistent terminology across artifacts

### Changes

**File: `CLAUDE.md` — Error Handling table**

Reorganize with consistent terminology:

```markdown
## Error Handling (All Agents)
| Error | Severity | Action |
|-------|----------|--------|
| Memory/ST/Context7/PostgreSQL MCP unavailable | NON_CRITICAL | Warn, proceed without |
| Beads unavailable | NON_CRITICAL | Skip beads phases |
| Plan not found | FATAL | EXIT — run /planner first |
| Plan not approved | FATAL | EXIT — run /plan-review first |
| PROJECT-KNOWLEDGE.md missing | NON_CRITICAL | Use profile above as defaults |
| **Review loop limit (3x)** | STOP_AND_WAIT | Show iteration summary, request user help |
| **Test/lint failure loop (3x)** | STOP_AND_WAIT | Show errors, request manual fix |
| **Exploration budget exceeded** | STOP_AND_TRANSITION | Summarize findings, transition to next sub-phase |
| Import violation | STOP_AND_FIX | Fix before proceeding |
| Loop limit exceeded (3x) | STOP | Show iteration summary, request user help |
```

Note: this consolidates the existing "Tests fail 3x" and "Loop limit exceeded (3x)" into more specific entries and adds the new exploration budget entry.

### Rationale
Consistent terminology makes it easier to reference rules across artifacts. The three-tier severity for loops (STOP_AND_WAIT / STOP_AND_TRANSITION / STOP_AND_FIX) creates a clear vocabulary.

### Self-Review

| Check | Status | Notes |
|-------|--------|-------|
| Backwards compatible | PARTIAL | Renames existing entries — need to update references |
| Not over-engineering | PASS | Clarification, not new functionality |
| Risk assessment | LOW | Documentation change |

**Verdict:** APPROVED — improves clarity. Update any artifacts that reference the old terminology.

---

## Implementation Order

### Phase 1: Core (do first)
1. **FIX-01** — Add vocabulary (CLAUDE.md + autonomy.md)
2. **FIX-02** — Add planner budgets (planner.md + task-analysis.md)
3. **FIX-03** — Add coder budgets (coder.md + coder-rules)

### Phase 2: Supporting
4. **FIX-05** — Add transition gates (planner.md + coder.md + checklists)
5. **FIX-04** — Lower delegation threshold (planner.md + coder.md)

### Phase 3: Observability
6. **FIX-06** — Sub-phase tracking (enrich-context.sh + checkpoint)
7. **FIX-07** — Exploration metrics (session-analytics.sh + pipeline-metrics)
8. **FIX-08** — Terminology (CLAUDE.md)

### Estimated Impact
- **Phase 1 alone** should resolve ~70% of exploration loop events (direct budget enforcement)
- **Phase 1 + Phase 2** should resolve ~90% (budgets + transition gates + delegation)
- **Phase 3** provides observability for the remaining ~10% edge cases

---

## Risk Assessment Summary

| Fix | Risk | Mitigation |
|-----|------|------------|
| FIX-01 | Low | Non-breaking vocabulary addition |
| FIX-02 | Medium | Budget numbers are heuristic — may need tuning; NEEDS_VALIDATION marker allows proceeding with gaps |
| FIX-03 | Medium | Tight budgets OK because VERIFY phase catches missed issues |
| FIX-04 | Low | code-researcher is well-tested |
| FIX-05 | Low | Lightweight gates; softened "no reads" to "no exploratory reads" |
| FIX-06 | Medium | Depends on session-transcript.jsonl; graceful degradation |
| FIX-07 | Low | Post-hoc only, non-breaking |
| FIX-08 | Low | Documentation change |

**Overall risk: LOW-MEDIUM.** All fixes are additive — no existing behavior is removed or broken. Budget numbers are initial heuristics subject to tuning.
