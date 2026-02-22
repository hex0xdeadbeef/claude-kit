#!/usr/bin/env bash
# verify-phase-completion.sh — Stop hook
# Deterministic check that all meta-agent phases completed before session ends.
#
# Hook contract:
#   stdin: JSON {"session_id":"...","transcript":"..."}
#   stdout: warning messages (informational)
#   exit 0 always
#
# Checks:
#   1. Run state file exists and has all 9 phases
#   2. No phase stuck in "running" state
#   3. Critical phases (VERIFY, CLOSE) were not skipped
#
# Phases: INIT, EXPLORE, ANALYZE, PLAN, CONSTITUTE, DRAFT, APPLY, VERIFY, CLOSE

set -euo pipefail

# Find the latest run state file
# Convention: .claude/agents/meta-agent/runs/<run_id>/progress.json
CLAUDE_DIR=""

# Try common locations
for dir in ".claude" "$HOME/.claude"; do
  if [[ -d "$dir/agents/meta-agent/runs" ]]; then
    CLAUDE_DIR="$dir"
    break
  fi
done

if [[ -z "$CLAUDE_DIR" ]]; then
  # No meta-agent runs found — this is fine, not every session uses meta-agent
  exit 0
fi

# Find most recent run directory
LATEST_RUN=$(ls -td "${CLAUDE_DIR}/agents/meta-agent/runs/"*/ 2>/dev/null | head -1)
if [[ -z "$LATEST_RUN" ]]; then
  exit 0
fi

PROGRESS_FILE="${LATEST_RUN}progress.json"
if [[ ! -f "$PROGRESS_FILE" ]]; then
  exit 0
fi

# Check if run is still active (not completed/aborted)
STATUS=$(jq -r '.status // "unknown"' "$PROGRESS_FILE" 2>/dev/null || echo "unknown")
if [[ "$STATUS" == "completed" ]] || [[ "$STATUS" == "aborted" ]]; then
  exit 0
fi

# Required phases
REQUIRED_PHASES=("INIT" "EXPLORE" "ANALYZE" "PLAN" "CONSTITUTE" "DRAFT" "APPLY" "VERIFY" "CLOSE")
CRITICAL_PHASES=("VERIFY" "CLOSE")

WARNINGS=()

# Check each required phase
for phase in "${REQUIRED_PHASES[@]}"; do
  PHASE_STATUS=$(jq -r ".phases.${phase}.status // \"missing\"" "$PROGRESS_FILE" 2>/dev/null || echo "missing")

  if [[ "$PHASE_STATUS" == "missing" ]] || [[ "$PHASE_STATUS" == "pending" ]]; then
    # Check if it's a critical phase
    for critical in "${CRITICAL_PHASES[@]}"; do
      if [[ "$phase" == "$critical" ]]; then
        WARNINGS+=("❌ CRITICAL: Phase ${phase} was NOT completed — this is required before session end")
      fi
    done
    if [[ "$PHASE_STATUS" == "missing" ]]; then
      WARNINGS+=("⚠️ Phase ${phase} was skipped")
    fi
  elif [[ "$PHASE_STATUS" == "running" ]]; then
    WARNINGS+=("⚠️ Phase ${phase} is still in 'running' state — possible incomplete execution")
  fi
done

# Output
if (( ${#WARNINGS[@]} > 0 )); then
  echo "🔍 META-AGENT PHASE COMPLETION CHECK:"
  for warn in "${WARNINGS[@]}"; do
    echo "  ${warn}"
  done
  echo ""
  echo "Run: ${LATEST_RUN}"
  echo "If this run is still in progress, these warnings are expected."
else
  echo "✅ All meta-agent phases completed successfully"
fi
