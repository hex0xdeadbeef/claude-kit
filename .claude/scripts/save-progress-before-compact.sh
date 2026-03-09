#!/bin/bash
# Hook: PreCompact
# Purpose: Save workflow state to stdout → additionalContext after compaction
# Non-blocking: compaction continues regardless

set -euo pipefail

# python3 required for reliable JSON generation
command -v python3 >/dev/null 2>&1 || {
  echo '{"additionalContext": "PreCompact hook: python3 not available"}'
  exit 0
}

python3 << 'PYTHON_EOF'
import json, os, glob

state_dir = ".claude/workflow-state"
parts = []

# Find latest checkpoint
checkpoints = sorted(glob.glob(os.path.join(state_dir, "*-checkpoint.yaml")))
if checkpoints:
    try:
        with open(checkpoints[-1]) as f:
            content = f.read()
        parts.append(f"## Workflow Checkpoint\nFile: {checkpoints[-1]}\n{content}")
    except Exception:
        pass

# Recent review completions
completions_file = os.path.join(state_dir, "review-completions.jsonl")
if os.path.isfile(completions_file):
    try:
        with open(completions_file) as f:
            lines = f.readlines()[-5:]
        if lines:
            parts.append("## Recent Review Completions\n" + "".join(lines))
    except Exception:
        pass

text = "\n\n".join(parts) if parts else "No workflow state found before compaction."
print(json.dumps({"additionalContext": text}))
PYTHON_EOF
