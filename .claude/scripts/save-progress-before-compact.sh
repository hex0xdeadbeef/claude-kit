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

def extract_yaml_section(text, section_name):
    """Extract lines belonging to a top-level YAML section (indent-based)."""
    lines = text.splitlines()
    in_section = False
    base_indent = -1
    result = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            if in_section:
                result.append("")
            continue
        indent = len(line) - len(line.lstrip())
        if not in_section:
            if stripped.startswith(section_name + ":"):
                in_section = True
                base_indent = indent
                val = stripped[len(section_name) + 1:].strip()
                if val:
                    result.append(val)
            continue
        if indent <= base_indent:
            break
        result.append(stripped)
    return result if result else None

# Find latest checkpoint
checkpoints = sorted(glob.glob(os.path.join(state_dir, "*-checkpoint.yaml")))
if checkpoints:
    try:
        with open(checkpoints[-1]) as f:
            content = f.read()

        # Structured summaries FIRST (survive truncation)
        handoff = extract_yaml_section(content, "handoff_payload")
        if handoff:
            parts.append("## Handoff Context\n" + "\n".join(f"  {l}" for l in handoff if l))

        issues = extract_yaml_section(content, "issues_history")
        if issues:
            parts.append("## Issues History\n" + "\n".join(f"  {l}" for l in issues if l))

        progress = extract_yaml_section(content, "implementation_progress")
        if progress:
            parts.append("## Implementation Progress\n" + "\n".join(f"  {l}" for l in progress if l))

        # Full checkpoint (may be truncated but summaries above survive)
        parts.append(f"## Workflow Checkpoint\nFile: {checkpoints[-1]}\n{content}")
    except Exception as e:
        parts.append(f"## Checkpoint Warning\nRead error: {checkpoints[-1]} — {e}")

# Recent review completions
completions_file = os.path.join(state_dir, "review-completions.jsonl")
if os.path.isfile(completions_file):
    try:
        with open(completions_file) as f:
            lines = f.readlines()[-5:]
        if lines:
            parts.append("## Recent Review Completions\n" + "".join(lines))
    except Exception as e:
        parts.append(f"## Checkpoint Warning\nRead error: {checkpoints[-1]} — {e}")

text = "\n\n".join(parts) if parts else "No workflow state found before compaction."
print(json.dumps({"additionalContext": text}))
PYTHON_EOF
