#!/usr/bin/env bash
# check-plan-drift.sh — PostToolUse hook (Write/Edit)
# Plan Drift Detection: warns when applied changes diverge from the approved plan.
#
# Hook contract:
#   stdin: JSON {"tool_name":"Write|Edit","tool_input":{"file_path":"...","content":"..."},"tool_result":{...}}
#   stdout: drift analysis (informational — PostToolUse cannot block, only warn)
#   exit 0 always (non-zero = hook ignored by Claude Code)
#
# How it works:
#   1. Finds the active meta-agent run (most recent .meta-agent/runs/*/progress.json)
#   2. Checks if current phase is APPLY (skip otherwise — drift only matters during APPLY)
#   3. Loads approved plan from checkpoints/plan.json
#   4. Compares written file path against planned change targets
#   5. If file not in plan → DRIFT WARNING (unplanned file)
#   6. Counts planned vs actual files to estimate overall drift %
#
# Limitations:
#   - Cannot do deep content-level diff (would require LLM)
#   - Checks file-level scope only: "was this file supposed to be changed?"
#   - Content-level drift detection left to VERIFY phase
#
# Dependencies: jq, find, bash 4+

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip agent-memory paths — avoid hook amplification loop during agent memory saves
if [[ "$FILE_PATH" == *"agent-memory"* ]]; then
  exit 0
fi

# ─── Guard: only check artifact files ─────────────────────────────────────────
if [[ ! "$FILE_PATH" =~ \.claude/ ]]; then
  exit 0
fi

# ─── Guard: only check Write and Edit tools ───────────────────────────────────
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

# ─── Find active run ──────────────────────────────────────────────────────────
# Look for .meta-agent/runs/ in common locations (project root or cwd)
RUNS_DIR=""
for candidate in ".meta-agent/runs" "${PWD}/.meta-agent/runs"; do
  if [[ -d "$candidate" ]]; then
    RUNS_DIR="$candidate"
    break
  fi
done

if [[ -z "$RUNS_DIR" ]]; then
  # No active runs — nothing to check
  exit 0
fi

# Find most recent run (latest directory by name, which is timestamp-prefixed)
LATEST_RUN=$(find "$RUNS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -r | head -1)

if [[ -z "$LATEST_RUN" ]]; then
  exit 0
fi

PROGRESS_FILE="${LATEST_RUN}/progress.json"
PLAN_FILE="${LATEST_RUN}/checkpoints/plan.json"

# ─── Guard: progress.json must exist ──────────────────────────────────────────
if [[ ! -f "$PROGRESS_FILE" ]]; then
  exit 0
fi

# ─── Guard: only check during APPLY phase ─────────────────────────────────────
CURRENT_PHASE=$(jq -r '.current_phase // empty' "$PROGRESS_FILE" 2>/dev/null)

if [[ "$CURRENT_PHASE" != "APPLY" ]]; then
  exit 0
fi

# ─── Guard: plan.json must exist ──────────────────────────────────────────────
if [[ ! -f "$PLAN_FILE" ]]; then
  echo "⚠️ PLAN_DRIFT: No plan.json found at ${PLAN_FILE} — cannot verify drift."
  echo "  Proceeding without drift check. Ensure VERIFY phase catches issues."
  exit 0
fi

# ─── Extract planned files from plan.json ─────────────────────────────────────
# Plan format expected: { "changes": [ {"file": "path", "action": "...", ...}, ... ] }
# Also support: { "planned_changes": [...] } or { "plan": { "changes": [...] } }
PLANNED_FILES=$(jq -r '
  (
    (.changes // []) +
    (.planned_changes // []) +
    ((.plan // {}).changes // [])
  ) | .[].file // empty
' "$PLAN_FILE" 2>/dev/null | sort -u)

if [[ -z "$PLANNED_FILES" ]]; then
  # Try alternate format: array of file paths directly
  PLANNED_FILES=$(jq -r '
    if type == "array" then .[] | .file // .path // empty
    else (.files // [])[]
    end
  ' "$PLAN_FILE" 2>/dev/null | sort -u)
fi

if [[ -z "$PLANNED_FILES" ]]; then
  echo "⚠️ PLAN_DRIFT: plan.json exists but no planned files found — cannot verify drift."
  echo "  Plan format may be incompatible. Expected: {\"changes\": [{\"file\": \"...\"}]}"
  exit 0
fi

# ─── Check if current file is in the plan ─────────────────────────────────────
# Normalize: strip leading ./ and compare with both full and relative paths
NORM_FILE=$(echo "$FILE_PATH" | sed 's|^\./||')
IS_PLANNED=false

while IFS= read -r planned; do
  NORM_PLANNED=$(echo "$planned" | sed 's|^\./||')
  if [[ "$NORM_FILE" == "$NORM_PLANNED" ]] || \
     [[ "$NORM_FILE" == *"$NORM_PLANNED" ]] || \
     [[ "$NORM_PLANNED" == *"$NORM_FILE" ]]; then
    IS_PLANNED=true
    break
  fi
done <<< "$PLANNED_FILES"

# ─── Track drift state ────────────────────────────────────────────────────────
# Use a temp file per run to accumulate applied files across multiple hook calls
DRIFT_STATE="${LATEST_RUN}/.drift_tracker"

# Record this file as applied
echo "$NORM_FILE" >> "$DRIFT_STATE" 2>/dev/null || true

# Count stats
PLANNED_COUNT=$(echo "$PLANNED_FILES" | grep -c '.' || true)
APPLIED_COUNT=0
UNPLANNED_COUNT=0

if [[ -f "$DRIFT_STATE" ]]; then
  APPLIED_FILES=$(sort -u "$DRIFT_STATE")
  APPLIED_COUNT=$(echo "$APPLIED_FILES" | grep -c '.' || true)

  # Count how many applied files are NOT in the plan
  while IFS= read -r applied; do
    found=false
    while IFS= read -r planned; do
      NORM_P=$(echo "$planned" | sed 's|^\./||')
      if [[ "$applied" == "$NORM_P" ]] || \
         [[ "$applied" == *"$NORM_P" ]] || \
         [[ "$NORM_P" == *"$applied" ]]; then
        found=true
        break
      fi
    done <<< "$PLANNED_FILES"
    if [[ "$found" == "false" ]]; then
      UNPLANNED_COUNT=$((UNPLANNED_COUNT + 1))
    fi
  done <<< "$APPLIED_FILES"
fi

# ─── Calculate drift percentage ───────────────────────────────────────────────
# Drift = unplanned files / total applied files
if (( APPLIED_COUNT > 0 )); then
  DRIFT_PCT=$(( (UNPLANNED_COUNT * 100) / APPLIED_COUNT ))
else
  DRIFT_PCT=0
fi

# ─── Output ───────────────────────────────────────────────────────────────────
if [[ "$IS_PLANNED" == "false" ]]; then
  echo "⚠️ PLAN_DRIFT: Unplanned file change detected!"
  echo "  File: ${FILE_PATH}"
  echo "  Status: NOT in approved plan (${PLAN_FILE})"
  echo "  Planned files: ${PLANNED_COUNT}"
  echo "  Applied so far: ${APPLIED_COUNT} (${UNPLANNED_COUNT} unplanned)"
  echo "  Drift: ${DRIFT_PCT}%"

  if (( DRIFT_PCT > 20 )); then
    echo ""
    echo "  ❌ DRIFT THRESHOLD EXCEEDED (${DRIFT_PCT}% > 20%)"
    echo "  Significant deviation from approved plan detected."
    echo "  Review changes before proceeding. Consider re-running PLAN phase."
  fi
else
  # Planned file — brief confirmation
  if (( DRIFT_PCT > 0 )); then
    echo "✅ PLAN_DRIFT: ${FILE_PATH} — in plan. Overall drift: ${DRIFT_PCT}% (${UNPLANNED_COUNT}/${APPLIED_COUNT} unplanned)"
  fi
  # If zero drift, stay silent (no noise for clean runs)
fi
