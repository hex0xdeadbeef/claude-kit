# Session Recovery

**Если сессия прервалась — checkpoint-first recovery:**

## Recovery Algorithm (Checkpoint-First)

```yaml
recovery_strategy:
  preferred: "Checkpoint-based (мгновенное восстановление)"
  fallback: "Heuristic-based (если checkpoint отсутствует)"
```

### Step 1: Check Checkpoint

```bash
# Найти последний checkpoint
CHECKPOINT=$(ls .claude/workflow-state/*-checkpoint.yaml 2>/dev/null | sort -t- -k2 | tail -1)
```

### Step 2A: Checkpoint Found → Resume

```yaml
checkpoint_recovery:
  steps:
    - "Read checkpoint file"
    - "Verify integrity (все обязательные поля заполнены)"
    - "Load handoff_payload как input для следующей фазы"
    - "Resume from phase_completed + 1"
    - "Restore iteration counters (plan_review: N/3, code_review: N/3)"

  example: |
    Checkpoint: phase_completed=2 (plan-review), verdict=APPROVED
    → Resume from Phase 3 (implementation)
    → Load handoff_payload с verdict и approved_with_notes
    → Iteration counters: plan_review=1/3, code_review=0/3
```

### Step 2B: No Checkpoint → Heuristic Fallback

```bash
# 1. Check for plan
PLAN=$(ls .claude/prompts/*.md 2>/dev/null | head -1)

# 2. Check for code changes
CHANGES=$(git diff master...HEAD --stat 2>/dev/null | wc -l)

# 3. Check tests (only if changes exist)
if [ "$CHANGES" -gt 0 ]; then
    TESTS=$(make test 2>&1 && echo "PASS" || echo "FAIL")  # adapt test command to project
fi

# Decision:
# - No plan              → Phase 1
# - Plan, no changes     → Phase 3
# - Changes, tests OK    → Phase 4
# - Changes, tests FAIL  → Phase 3 (fix)
```

## Decision Table

```yaml
session_recovery:
  # Checkpoint-based (preferred)
  - checkpoint_exists: true
    action: "Read checkpoint → resume from phase_completed + 1"
    note: "Мгновенное восстановление с полным контекстом"

  # Heuristic fallback
  - checkpoint_exists: false
    plan_exists: false
    code_changes: "-"
    tests_pass: "-"
    resume_from: "Phase 1: Planning"

  - checkpoint_exists: false
    plan_exists: true
    code_changes: false
    tests_pass: "-"
    resume_from: "Phase 3: Implementation"
    warning: "⚠️ Iteration counters lost — assume iteration 1/3"

  - checkpoint_exists: false
    plan_exists: true
    code_changes: true
    tests_pass: false
    resume_from: "Phase 3: Fix tests"

  - checkpoint_exists: false
    plan_exists: true
    code_changes: true
    tests_pass: true
    resume_from: "Phase 4: Code Review"
```

## Quick Check Commands

```bash
ls .claude/workflow-state/*-checkpoint.yaml  # Checkpoint exists?
ls .claude/prompts/                          # Plan exists?
bd list --status=in_progress                 # Active beads task?
git diff master...HEAD --stat                # Code changes?
make test                                    # Tests pass? (adapt to project)
```

## Checkpoint File Format

```yaml
# .claude/workflow-state/{feature}-checkpoint.yaml
feature: "{feature-name}"
phase_completed: 2
phase_name: "plan-review"
iteration:
  plan_review: "1/3"
  code_review: "0/3"
verdict: "APPROVED"
timestamp: "2026-02-20T14:30:00Z"
complexity: "L"
route: "standard"
handoff_payload:
  to: "coder"
  artifact: ".claude/prompts/{feature}.md"
  verdict: "APPROVED"
  issues_summary: { blocker: 0, major: 0, minor: 1 }
  approved_with_notes: ["Part 3: minor — add error context in helper"]
  iteration: "1/3"
issues_history:
  - phase: 2
    iteration: 1
    issues: ["PR-001: MINOR — missing error context in Part 3"]
```

## SEE ALSO

- `workflow-phases.md` — Phase execution and loop limits
- `shared-autonomy.md` — RESUME autonomy mode
