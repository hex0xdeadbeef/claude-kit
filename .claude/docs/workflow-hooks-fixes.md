# Workflow Hooks — Proposed Fixes

**Date:** 2026-03-20
**Companion to:** [workflow-hooks-research.md](workflow-hooks-research.md)
**Format:** For each issue: proposed fix → self-review → verdict

---
## FIX-05: Unify Exploration Loop Detection (P2)

### Problem
Exploration loop detection fragmented across 4 artifacts with inconsistent thresholds (10/10/30/undefined).

### Proposed Fix
Define a single source of truth for exploration thresholds in `CLAUDE.md` error handling table, and reference it from all detection points.

**File:** `CLAUDE.md` — update error handling table

**Current row:**
```
| Exploration budget exceeded | STOP_AND_TRANSITION | Summarize findings, transition to next sub-phase |
```

**Proposed replacement:**
```
| Exploration budget exceeded (reads > 20 in sub-phase, ratio > 10 session-wide) | STOP_AND_TRANSITION | Summarize findings, transition to next sub-phase |
```

**File:** `enrich-context.sh` — align threshold

**Current (line 93):**
```python
if recent_reads > 10 and recent_writes == 0:
```

**Proposed:**
```python
if recent_reads > 15 and recent_writes == 0:
```

**Rationale:** Increase from 10 to 15 for context signal. The 10-read threshold is too aggressive — a normal planner research phase easily hits 10 reads. 15 is the compromise between false negatives and false positives.

**File:** `pipeline-metrics.md` — align anomaly rule

**Current (line 100-101):**
```yaml
- condition: "exploration_reads > 30 AND action_writes == 0"
  warning: "Session appears stuck in exploration"
```

**Proposed:**
```yaml
- condition: "exploration_reads > 30 AND action_writes == 0 AND NOT project_researcher_session"
  warning: "Session appears stuck in exploration"
```

**Rationale:** Add exclusion for Project Researcher sessions (read-heavy by design). Detection: check if checkpoint feature contains "project-research" or if session started with `/project-researcher`.

**File:** `checkpoint-protocol.md` — add threshold to sub_phase fields

**Current (lines 42-45):**
```yaml
fields:
  current: "RESEARCH|DESIGN|DOCUMENT|EVALUATE|IMPLEMENT|VERIFY"
  tool_calls_in_sub_phase: "N (count of tool calls since sub-phase start)"
  file_reads_in_sub_phase: "N (count of Read/Grep/Glob calls since sub-phase start)"
```

**Proposed:**
```yaml
fields:
  current: "RESEARCH|DESIGN|DOCUMENT|EVALUATE|IMPLEMENT|VERIFY"
  tool_calls_in_sub_phase: "N (count of tool calls since sub-phase start)"
  file_reads_in_sub_phase: "N (count of Read/Grep/Glob calls since sub-phase start)"
  budget_threshold: "20 reads per sub-phase (see CLAUDE.md error table)"
  on_exceeded: "STOP_AND_TRANSITION to next sub-phase"
```

### Self-Review

| Check                         | Result   | Notes                                                            |
| ----------------------------- | -------- | ---------------------------------------------------------------- |
| Single source of truth?       | PARTIAL  | CLAUDE.md defines thresholds, but 4 consumers still need updates |
| Backward compatible?          | YES      | Increasing threshold from 10→15 reduces false positives          |
| Project Researcher exemption? | YES      | Explicit exclusion in pipeline-metrics                           |
| Threshold values justified?   | PARTIAL  | 15/20/30 are reasonable but not data-driven                      |
| Cross-artifact consistency?   | IMPROVED | Still 3 different numbers (15/20/30) for 3 different scopes      |

**Concerns:**
1. **Still 3 thresholds:** Context (15 recent calls), sub-phase (20 reads), session (30 reads). This is inherent to the 3 different scopes but could be confusing.
2. **Project Researcher detection:** Checking checkpoint feature name is fragile. Better: add `session_type` field to checkpoint (values: workflow, project-research, ad-hoc).
3. **No automated tests:** Cannot validate threshold effectiveness without real session data.

**Verdict: APPROVED WITH CHANGES**
- Add `session_type` field to checkpoint-protocol.md (not just feature name detection)
- Document the 3-scope model explicitly in CLAUDE.md or a new protocol file
- Accept that thresholds will need data-driven tuning over time

---

## FIX-03: Automated `go vet` in PostToolUse (P2)

### Problem
`go vet` never runs automatically between PostToolUse and VERIFY phase.

### Proposed Fix
**Option A:** Add `go vet` to `auto-fmt-go.sh` after gofmt.
**Option B:** Create separate `go-vet.sh` PostToolUse hook.
**Recommended:** Option A (fewer moving parts, same trigger conditions).

**File:** `.claude/scripts/auto-fmt-go.sh` — add go vet after gofmt

**Current (lines 97-105):**
```bash
if command -v gofmt >/dev/null 2>&1; then
  if gofmt -w "$FILE_PATH" 2>/dev/null; then
    echo "[...] auto-fmt-go: formatted $(basename "$FILE_PATH")" >> "$LOG_FILE"
  fi
else
  echo "[...] auto-fmt-go: WARNING gofmt not found, skipping" >> "$LOG_FILE"
fi
```

**Proposed:**
```bash
if command -v gofmt >/dev/null 2>&1; then
  if gofmt -w "$FILE_PATH" 2>/dev/null; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] auto-fmt-go: formatted $(basename "$FILE_PATH")" >> "$LOG_FILE"
  fi
else
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] auto-fmt-go: WARNING gofmt not found, skipping" >> "$LOG_FILE"
fi

# go vet — incremental static analysis (informational only, non-blocking)
if command -v go >/dev/null 2>&1; then
  VET_OUTPUT=$(go vet "./${FILE_PATH%/*}/..." 2>&1) || {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] auto-fmt-go: go vet issues in $(basename "$FILE_PATH"):" >> "$LOG_FILE"
    echo "$VET_OUTPUT" >> "$LOG_FILE"
    # Output to stdout so Claude sees the warning (PostToolUse is informational)
    echo "⚠ go vet: $VET_OUTPUT"
  }
fi
```

### Self-Review

| Check            | Result  | Notes                                             |
| ---------------- | ------- | ------------------------------------------------- |
| Non-blocking?    | YES     | PostToolUse cannot block — informational only     |
| Performance?     | CONCERN | `go vet` on package can take 1-3s per file write  |
| False positives? | LOW     | `go vet` is well-tuned in Go ecosystem            |
| Incremental?     | YES     | Vets only the package containing the changed file |
| Consistent?      | YES     | Same script, same event, same matcher             |

**Concerns:**
1. **Performance:** Running `go vet` on EVERY `.go` file write adds 1-3s per write. For a 10-file implementation, that's 10-30s of overhead. Consider: only run if file write was successful AND no recent vet within 30s.
2. **Package path computation:** `${FILE_PATH%/*}/...` assumes file is in a Go package directory. Edge case: file at repo root. Fix: use `go vet ./...` for root-level files.
3. **Noise:** Outputting vet warnings to stdout on every write could be verbose. Alternative: only warn once per unique issue per session.

**Verdict: NEEDS_CHANGES**
- Performance is the main concern. Running `go vet` on every write is too aggressive.
- **Revised proposal:** Add `go vet ./...` to VERIFY phase only (before `make lint`), not to PostToolUse. This gives earlier feedback than `make lint` without per-write overhead.
- Update `coder.md` VERIFY phase to explicitly include `go vet ./...` before `make lint`:
  ```
  VERIFY: go vet ./... && make fmt && make lint && make test
  ```
- This is safer, faster, and more predictable than per-file vet.

---

## FIX-07: Post-Commit Actions via PreToolUse Gate (P2)

### Problem
No `PostCommit` hook event in Claude Code. Cannot run actions after commit.

### Proposed Fix
Since we can't add a PostCommit event, implement via **two-phase approach:**

1. **PreToolUse on `git commit`** — validate before commit (FIX-01 handles build check)
2. **Completion phase inline logic** — handle post-commit actions in orchestration-core.md

**File:** `orchestration-core.md` Phase 5 — add commit message template

**Current (lines 38-44):**
```
**Phase 5 — Completion:** After code-review APPROVED/APPROVED_WITH_COMMENTS:
1. Create git commit (MANDATORY)
2. Run `bd sync` (if beads active)
...
```

**Proposed:**
```
**Phase 5 — Completion:** After code-review APPROVED/APPROVED_WITH_COMMENTS:
1. Create git commit (MANDATORY)
   - Message format: `{type}({scope}): {description}`
   - Co-Authored-By: included by default (Claude Code system behavior)
   - To strip: user sets `GIT_STRIP_CO_AUTHOR=true` in settings.local.json env
2. Run `bd sync` (if beads active)
...
```

**For Co-Authored-By stripping (if user wants):**

**File:** `.claude/settings.local.json.example` — add env var example

```json
{
  "env": {
    "GIT_STRIP_CO_AUTHOR": "false"
  }
}
```

**File:** Add git hook template (standard git, not Claude Code hook):

`.claude/templates/git-hooks/post-commit`
```bash
#!/bin/bash
# Optional: strip Co-Authored-By from commit messages
# Install: cp .claude/templates/git-hooks/post-commit .git/hooks/post-commit && chmod +x .git/hooks/post-commit

if [[ "${GIT_STRIP_CO_AUTHOR:-false}" == "true" ]]; then
    MSG=$(git log -1 --format=%B)
    CLEAN_MSG=$(echo "$MSG" | sed '/^Co-Authored-By:/d')
    if [[ "$MSG" != "$CLEAN_MSG" ]]; then
        git commit --amend -m "$CLEAN_MSG" --no-verify
    fi
fi
```

### Self-Review

| Check                         | Result  | Notes                                                       |
| ----------------------------- | ------- | ----------------------------------------------------------- |
| Works within platform limits? | YES     | Uses git hooks (not Claude Code hooks) for post-commit      |
| Opt-in only?                  | YES     | Requires explicit env var + manual install                  |
| Safe default?                 | YES     | Co-Authored-By preserved by default                         |
| Consistent?                   | YES     | Template pattern matches existing onboarding templates      |
| Amend safety?                 | CONCERN | `--amend` rewrites history — safe for unpushed commits only |

**Concerns:**
1. **`git commit --amend`** in post-commit hook rewrites the commit that was just created. This is safe for local-only commits but dangerous if auto-push is enabled.
2. **`--no-verify`** bypasses pre-commit hooks — necessary to avoid infinite loop (commit → post-commit → amend → pre-commit → ...) but contradicts project's "never skip hooks" policy.
3. **Alternative approach:** Instead of post-commit stripping, use `prepare-commit-msg` git hook to prevent addition. But Claude Code controls the commit message programmatically, so this may not work.

**Verdict: APPROVED WITH CHANGES**
- Add warning in template: "Do NOT use with auto-push. Only for local development."
- Document the `--no-verify` necessity explicitly
- Consider alternative: `commit-msg` git hook (edits message before commit is finalized) instead of `post-commit` + amend. This is cleaner:

```bash
#!/bin/bash
# .git/hooks/commit-msg — strip Co-Authored-By before commit
if [[ "${GIT_STRIP_CO_AUTHOR:-false}" == "true" ]]; then
    sed -i '' '/^Co-Authored-By:/d' "$1"
fi
```

This is the **recommended approach** — no amend, no `--no-verify`, clean and safe.

---

## FIX-02: Commit Message Template (P3)

### Problem
No commit message format defined in workflow. Inconsistent messages across runs.

### Proposed Fix
Add commit message template to `orchestration-core.md` Phase 5.

**File:** `orchestration-core.md` — add after step 1

**Proposed addition:**
```yaml
commit_message_format:
  template: |
    {type}({scope}): {description}

    {body — optional, max 3 lines}

    Plan: .claude/prompts/{feature}.md
    Complexity: {S|M|L|XL}
    Review iterations: PR {N}/3, CR {N}/3
  types: "feat|fix|refactor|test|docs|chore"
  scope: "package or module name"
  description: "imperative mood, max 72 chars"
```

### Self-Review

| Check                         | Result | Notes                                    |
| ----------------------------- | ------ | ---------------------------------------- |
| Follows conventional commits? | YES    | type(scope): description                 |
| Includes pipeline context?    | YES    | Plan path, complexity, iterations        |
| Enforced by hook?             | NO     | Documentation only — no enforcement hook |
| Backward compatible?          | YES    | Additive change to orchestration-core.md |

**Verdict: APPROVED** — Documentation improvement, no enforcement (too rigid for all projects).

---

## FIX-08: Validate VERIFY Command Existence (P2)

### Problem
VERIFY commands assume `make fmt/lint/test` exist without validation.

### Proposed Fix
Add Makefile existence check to `coder.md` VERIFY phase startup.

**File:** `coder.md` — add to VERIFY phase (before running commands)

**Proposed addition:**
```yaml
verify_startup:
  step_0: "Check VERIFY command availability"
  checks:
    - if: "PROJECT-KNOWLEDGE.md exists AND defines custom VERIFY"
      then: "Use custom VERIFY command"
    - if: "Makefile exists with fmt/lint/test targets"
      then: "Use make-based VERIFY: make fmt && make lint && make test"
    - if: "go.mod exists but no Makefile"
      then: "Use Go-native VERIFY: go fmt ./... && go vet ./... && go test ./..."
    - else: "WARN: No VERIFY command available. Skip VERIFY, note in handoff."
  note: "This ensures VERIFY never fails due to missing build tooling"
```

### Self-Review

| Check                          | Result  | Notes                                                           |
| ------------------------------ | ------- | --------------------------------------------------------------- |
| Handles missing Makefile?      | YES     | Fallback to Go-native commands                                  |
| Respects PROJECT-KNOWLEDGE.md? | YES     | Custom override takes priority                                  |
| Fails gracefully?              | YES     | Warns but doesn't block if no VERIFY possible                   |
| Consistent with CLAUDE.md?     | PARTIAL | CLAUDE.md still defines default commands — should note fallback |

**Concerns:**
1. CLAUDE.md defines `VERIFY=make fmt && make lint && make test` as the authoritative command. Adding fallback in coder.md creates two sources of truth.
2. Better: make CLAUDE.md the single source, and have Project Researcher generate the correct VERIFY command during `CLAUDE.md` generation (it already does detection).

**Verdict: APPROVED WITH CHANGES**
- Add fallback logic to `coder.md` VERIFY phase
- Add note to `CLAUDE.md`: "VERIFY command may be overridden by PROJECT-KNOWLEDGE.md or detected by /project-researcher"
- Update Project Researcher's GENERATION phase to always validate Makefile existence before defaulting to `make`-based commands

---

## FIX-06: Workflow-Aware `check-uncommitted.sh` (P3)

### Problem
`check-uncommitted.sh` blocks stop for ANY uncommitted changes, even in non-workflow sessions.

### Proposed Fix
Check for active workflow checkpoint before blocking. If no workflow active, warn but don't block.

**File:** `.claude/scripts/check-uncommitted.sh` — add workflow detection

**Current logic:** Block if any uncommitted files.

**Proposed logic:**
```bash
# Check if workflow is active (checkpoint exists)
CHECKPOINT=$(ls .claude/workflow-state/*-checkpoint.yaml 2>/dev/null | tail -1)
IS_WORKFLOW="false"
if [[ -n "$CHECKPOINT" ]]; then
    IS_WORKFLOW="true"
fi

if [ "$UNCOMMITTED" -gt 0 ]; then
    if [[ "$IS_WORKFLOW" == "true" ]]; then
        # Workflow active — BLOCK (must commit before stopping)
        # ... existing block logic ...
    else
        # No workflow — WARN only (don't block non-workflow sessions)
        echo "WARNING: $UNCOMMITTED uncommitted file(s). Consider committing." >&2
        exit 0
    fi
fi
```

### Self-Review

| Check                            | Result   | Notes                                                     |
| -------------------------------- | -------- | --------------------------------------------------------- |
| Workflow sessions still blocked? | YES      | Checkpoint exists → block                                 |
| Non-workflow sessions unblocked? | YES      | No checkpoint → warn only                                 |
| Edge case: stale checkpoint?     | CONCERN  | Old checkpoint from previous session triggers false block |
| Project Researcher impact?       | IMPROVED | No longer blocks after artifact generation                |

**Concerns:**
1. **Stale checkpoint:** A checkpoint from a previous session may exist. Need to also check if checkpoint is recent (e.g., within last 2 hours) or if phase_completed < 5 (not yet completed).
2. **False negative:** If a workflow crashes before writing checkpoint (Phase 0.5 → no checkpoint yet), uncommitted changes won't be blocked.

**Verdict: APPROVED WITH CHANGES**
- Add staleness check: only treat checkpoint as "active" if `phase_completed < 5` (not yet completed)
- Add timestamp check: checkpoint mtime within last 4 hours

---

## FIX-04: Log gofmt Failures (P4)

### Problem
`auto-fmt-go.sh` silently swallows gofmt failures.

### Proposed Fix
Log failure details to hook-log.txt (keep non-blocking behavior).

**File:** `.claude/scripts/auto-fmt-go.sh` — update gofmt section

**Current (lines 98-101):**
```bash
if gofmt -w "$FILE_PATH" 2>/dev/null; then
    echo "[...] auto-fmt-go: formatted $(basename "$FILE_PATH")" >> "$LOG_FILE"
fi
```

**Proposed:**
```bash
FMT_OUTPUT=$(gofmt -w "$FILE_PATH" 2>&1) || {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] auto-fmt-go: gofmt FAILED on $(basename "$FILE_PATH"): $FMT_OUTPUT" >> "$LOG_FILE"
}
if [[ $? -eq 0 ]]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] auto-fmt-go: formatted $(basename "$FILE_PATH")" >> "$LOG_FILE"
fi
```

### Self-Review

| Check                   | Result  | Notes                    |
| ----------------------- | ------- | ------------------------ |
| Non-blocking preserved? | YES     | Still exit 0             |
| Failure logged?         | YES     | To hook-log.txt          |
| Noise to Claude?        | NO      | Logs to file, not stdout |
| Performance?            | NEUTRAL | Same gofmt call          |

**Verdict: APPROVED** — Minimal, safe improvement.

---

## Summary of Verdicts

| Fix                              | Verdict                   | Key Changes Required                                      |
| -------------------------------- | ------------------------- | --------------------------------------------------------- |
| FIX-09 (JSON injection)          | **APPROVED**              | Direct implementation                                     |
| FIX-01 (pre-commit build)        | **APPROVED WITH CHANGES** | Use env var for BUILD_OUTPUT, add CLAUDE.md error entry   |
| FIX-05 (exploration unification) | **APPROVED WITH CHANGES** | Add session_type to checkpoint, document 3-scope model    |
| FIX-03 (go vet)                  | **NEEDS_CHANGES**         | Move to VERIFY phase instead of PostToolUse               |
| FIX-07 (Co-Authored-By)          | **APPROVED WITH CHANGES** | Use commit-msg hook instead of post-commit+amend          |
| FIX-02 (commit template)         | **APPROVED**              | Documentation only                                        |
| FIX-08 (VERIFY validation)       | **APPROVED WITH CHANGES** | Single source of truth in CLAUDE.md, fallback in coder.md |
| FIX-06 (workflow-aware stop)     | **APPROVED WITH CHANGES** | Add staleness + completion check                          |
| FIX-04 (log gofmt failures)      | **APPROVED**              | Direct implementation                                     |

### Implementation Order

```
Phase 1 (P0 — immediate):
  └── FIX-09: Secure JSON in save-review-checkpoint.sh

Phase 2 (P1 — build safety):
  └── FIX-01: Pre-commit build validation hook

Phase 3 (P2 — exploration + vet + verify):
  ├── FIX-05: Unify exploration detection
  ├── FIX-03: go vet in VERIFY phase
  └── FIX-08: VERIFY command validation

Phase 4 (P3 — polish):
  ├── FIX-07: Co-Authored-By management
  ├── FIX-02: Commit message template
  ├── FIX-06: Workflow-aware stop hook
  └── FIX-04: Log gofmt failures
```

### Files Requiring Changes

| File                                                       | Fixes Applied                                                     |
| ---------------------------------------------------------- | ----------------------------------------------------------------- |
| `.claude/scripts/save-review-checkpoint.sh`                | FIX-09                                                            |
| `.claude/scripts/auto-fmt-go.sh`                           | FIX-04                                                            |
| `.claude/scripts/check-uncommitted.sh`                     | FIX-06                                                            |
| `.claude/settings.json`                                    | FIX-01 (new hook registration)                                    |
| `.claude/scripts/pre-commit-build.sh`                      | FIX-01 (new file)                                                 |
| `.claude/skills/workflow-protocols/orchestration-core.md`  | FIX-02, FIX-07                                                    |
| `.claude/skills/workflow-protocols/checkpoint-protocol.md` | FIX-05                                                            |
| `.claude/skills/workflow-protocols/pipeline-metrics.md`    | FIX-05                                                            |
| `.claude/scripts/enrich-context.sh`                        | FIX-05                                                            |
| `.claude/commands/coder.md`                                | FIX-03, FIX-08                                                    |
| `CLAUDE.md`                                                | FIX-01 (error table), FIX-05 (thresholds), FIX-08 (fallback note) |
| `.claude/templates/git-hooks/commit-msg`                   | FIX-07 (new file)                                                 |
| `.claude/settings.local.json.example`                      | FIX-07 (env var)                                                  |
