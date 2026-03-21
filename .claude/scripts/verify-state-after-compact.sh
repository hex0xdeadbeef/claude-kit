#!/bin/bash
# Hook: PostCompact
# Purpose: Verify workflow state integrity after compaction, re-inject critical state if needed
# Non-blocking: exit 0 always
#
# Checks:
#   1. Checkpoint file exists and is readable
#   2. review-completions.jsonl is valid JSONL (each line parses as JSON)
#   3. Re-injects key state fields (phase, iteration, feature) as additionalContext
#      so the model has them even if PreCompact additionalContext was truncated
#
# Output: JSON with additionalContext containing state verification result

set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo '{"additionalContext": "PostCompact: python3 not available, state verification skipped"}'
  exit 0
}

python3 << 'PYTHON_EOF'
import json, os, glob

state_dir = ".claude/workflow-state"
warnings = []
state_summary = []

# 1. Verify checkpoint
checkpoints = sorted(glob.glob(os.path.join(state_dir, "*-checkpoint.yaml")))
if checkpoints:
    latest = checkpoints[-1]
    try:
        with open(latest) as f:
            content = f.read()
        if not content.strip():
            warnings.append(f"Checkpoint file empty: {latest}")
        else:
            # Extract key fields for re-injection
            fields = {}
            for line in content.splitlines():
                stripped = line.strip()
                if ":" in stripped and not stripped.startswith("-") and not stripped.startswith("#"):
                    key, _, val = stripped.partition(":")
                    key = key.strip()
                    val = val.strip().strip('"').strip("'")
                    if key in ("phase_completed", "phase_name", "complexity", "route",
                               "plan_review_iteration", "code_review_iteration", "feature"):
                        fields[key] = val
            feature = os.path.basename(latest).replace("-checkpoint.yaml", "")
            fields["feature"] = feature
            state_summary.append(f"Checkpoint OK: {latest}")
            state_summary.append(f"  feature={fields.get('feature', '?')}, "
                                 f"phase={fields.get('phase_completed', '?')}/{fields.get('phase_name', '?')}, "
                                 f"complexity={fields.get('complexity', '?')}, "
                                 f"plan_review_iter={fields.get('plan_review_iteration', '0')}, "
                                 f"code_review_iter={fields.get('code_review_iteration', '0')}")
    except Exception as e:
        warnings.append(f"Checkpoint read error: {latest} — {e}")
else:
    state_summary.append("No checkpoint found (not in workflow or first phase)")

# 2. Verify review-completions.jsonl
completions_file = os.path.join(state_dir, "review-completions.jsonl")
if os.path.isfile(completions_file):
    try:
        with open(completions_file) as f:
            lines = f.readlines()
        valid = 0
        invalid = 0
        for i, line in enumerate(lines):
            line = line.strip()
            if not line:
                continue
            try:
                json.loads(line)
                valid += 1
            except json.JSONDecodeError:
                invalid += 1
                if invalid <= 3:
                    warnings.append(f"Invalid JSONL at line {i+1}: {line[:80]}")
        state_summary.append(f"Review completions: {valid} valid entries" +
                             (f", {invalid} invalid" if invalid else ""))
    except Exception as e:
        warnings.append(f"Review completions read error: {e}")

# 3. Build output
parts = []
if warnings:
    parts.append("## PostCompact Warnings\n" + "\n".join(f"- {w}" for w in warnings))
if state_summary:
    parts.append("## Workflow State (verified)\n" + "\n".join(state_summary))

if parts:
    text = "\n\n".join(parts)
else:
    text = "PostCompact: no workflow state to verify"

print(json.dumps({"additionalContext": text}))
PYTHON_EOF
exit 0
