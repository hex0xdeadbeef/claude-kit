---
feature: fix-code-reviewer-turn-drain
status: approved
complexity: L
task_type: bug_fix
created: 2026-03-30
---

# Design Spec: Fix code-reviewer turn drain & missing verdict

## Context

code-reviewer runs with `isolation: worktree` and has `Write`/`Edit` tools for memory saves.
When the agent writes to `.claude/agent-memory/code-reviewer/`, three PostToolUse hooks fire:
- `yaml-lint.sh` (on `Edit(.claude/**)`)
- `check-references.sh` (on `Write(.claude/**)`)
- `check-plan-drift.sh` (on `Write(.claude/**)` and `Edit(.claude/**)`)

These hooks produce lint/reference feedback that the agent treats as actionable — triggering
more `Write`/`Edit` calls to "fix" the issues, which fires the hooks again. This loop can
consume 25–35 of the agent's 45 turns before the actual review begins. Result: no verdict,
orchestrator hits `output_validation.on_incomplete_output`, but `SendMessage` is unavailable
as a deferred tool → manual verdict fallback required every time.

## Requirements

### Scope IN
- Prevent PostToolUse hooks from firing on `.claude/agent-memory/**` writes
- Harden RULE_5 turn budget: force verdict output when turns are running low
- Fix orchestrator output_validation fallback when `SendMessage` is unavailable

### Scope OUT
- Do NOT change agent memory architecture (agent keeps Write/Edit, keeps writing memory)
- Do NOT change hook behavior for non-agent-memory `.claude/**` paths
- Do NOT change SubagentStop hook or sync-agent-memory.sh
- Do NOT modify plan-reviewer (same hooks apply but it doesn't write memory)

## Selected Approach: B — Script Guards + RULE_5 Hardening + Orchestrator Fallback

### Problem 1: Hook amplification (root cause)

Add a path-guard at the top of each of the three hook scripts.
Each script reads the file path from `$CLAUDE_TOOL_INPUT` and exits 0 (silently) if
the path contains `agent-memory`.

**Why scripts, not settings.json patterns:**
settings.json `if` patterns can't express "match `.claude/**` except `.claude/agent-memory/**`"
without duplicating entries for every `.claude/` subdir. Adding a new subdir would silently
break the exclusion. A script-level guard is self-contained and path-aware.

**Affected scripts:**
- `.claude/agents/meta-agent/scripts/yaml-lint.sh`
- `.claude/agents/meta-agent/scripts/check-references.sh`
- `.claude/agents/meta-agent/scripts/check-plan-drift.sh`

### Problem 2: RULE_5 turn budget enforcement

Current RULE_5: "If you have used 33+ tool calls, IMMEDIATELY skip to VERDICT and form output."

Problem: the agent is already in a lint-fix loop at turn 33 and ignores the rule.

Fix: Add an earlier, harder trigger in code-reviewer.md:
- At turn **25**: emit a self-check warning — "Review progress check: N turns used. If review not started, abort memory/lint work immediately and begin GET CHANGES."
- At turn **33**: hard abort — output `VERDICT: CHANGES_REQUESTED` with note "Review incomplete due to turn exhaustion" if no review sections completed yet.

This makes RULE_5 a countdown rather than a one-line instruction.

### Problem 3: output_validation fallback

Current flow (workflow.md `output_validation.on_incomplete_output`):
1. SendMessage to same agent → get verdict
2. If SendMessage fails → ask user for manual verdict

Problem: `SendMessage` is not available as a deferred tool, so step 2 always triggers.

Fix: Replace step 1 with a check for SendMessage availability. If unavailable,
re-delegate to code-reviewer agent with a minimal "verdict-only" prompt:
> "The previous code review did not return a verdict. Read `.claude/workflow-state/review-completions.jsonl`
> for context. Output ONLY: `VERDICT: {verdict}` followed by a brief handoff."

This is a targeted re-launch, not a full review cycle — the new agent reads the checkpoint
written by the SubagentStop hook (which fired on the first run).

## Key Decisions

1. **Script guards use `exit 0` (silent skip), not a warning message**
   - Rationale: PostToolUse cannot block, but stdout/stderr from hooks IS shown to agent.
     Any output on agent-memory writes would still distract the agent.
   - Impact: Zero visibility when agent-memory writes are skipped. Acceptable — these are
     internal memory operations, not artifact changes that need linting.

2. **RULE_5 trigger at turn 25, not earlier**
   - Rationale: Normal review with Sequential Thinking uses ~20 turns for QUICK CHECK +
     GET CHANGES + REVIEW. Turn 25 is early enough to catch runaway loops but late enough
     not to interrupt legitimate reviews.
   - Impact: Agent may output partial review in legitimate large-diff scenarios.
     Mitigated by the RULE_5 text: "if review not started" — the trigger is conditional.

3. **output_validation fallback uses re-launch, not SendMessage**
   - Rationale: SendMessage is not in the deferred tools list. A re-launch with minimal
     context is reliable and preserves pipeline continuity.
   - Impact: Adds ~1 agent round trip on failure. Acceptable vs. manual intervention every time.

4. **check-plan-drift.sh guard uses same pattern as other scripts**
   - Rationale: check-plan-drift.sh fires on BOTH Write and Edit hooks for `.claude/**`.
     Guard must be added once — at script entry, not per hook entry.
   - Impact: Plan drift is not checked for agent-memory files. Correct — agent-memory is
     not a plan artifact.

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Script guard reads wrong field from CLAUDE_TOOL_INPUT | MEDIUM | Test with `echo '{"file_path": ".claude/agent-memory/x.md"}' | script` before merge |
| RULE_5 turn-25 trigger fires on large legitimate diffs | LOW | Trigger is conditional ("if review not started") — normal reviews won't hit it |
| output_validation re-launch creates infinite retry loop | LOW | Max 1 retry already documented in `max_retries: 1`; re-launch inherits this limit |
| yaml-lint.sh uses different field name than check-references.sh | LOW | Explore both scripts before writing guard; use `// .path // ""` fallback chain |

## Acceptance Criteria

- [ ] Agent writing to `.claude/agent-memory/code-reviewer/*.md` does NOT produce hook output visible to the agent
- [ ] Agent writing to `.claude/rules/*.md` STILL triggers yaml-lint, check-references, check-plan-drift (unchanged behavior)
- [ ] code-reviewer.md RULE_5 section contains explicit turn-25 self-check and turn-33 hard abort
- [ ] workflow.md `output_validation.on_incomplete_output` does not reference SendMessage as primary step; re-launch is step 1
- [ ] Full review cycle completes with verdict in ≥ 9/10 test runs (previously ~5/10)
