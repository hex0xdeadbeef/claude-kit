#!/bin/bash
# Hook: SubagentStart (matcher: plan-reviewer, code-reviewer — separate entries)
# Purpose: Inject workflow context as additionalContext for review agents
# Non-blocking: exit 0 always (context injection is additive, never blocks agent)
#
# Usage: inject-review-context.sh <agent-type>
#   agent-type: "plan-reviewer" or "code-reviewer" (passed from settings.json matcher)
#
# Data sources:
#   1. .claude/workflow-state/*-checkpoint.yaml — pipeline state
#   2. .claude/workflow-state/review-completions.jsonl — prior verdicts
#   3. .claude/prompts/*-spec.md — spec existence (L/XL)
#   4. .claude/prompts/*.md — plan existence
#
# Output: {"additionalContext": "..."} JSON on stdout (target: 1-3K chars of 10K limit)

set -euo pipefail

AGENT_TYPE="${1:-unknown}"

# Consume stdin (SubagentStart payload — not needed, but must be read to avoid SIGPIPE)
cat > /dev/null

command -v python3 >/dev/null 2>&1 || {
  echo '{"additionalContext": "[Workflow Context] python3 not available — context injection skipped"}'
  exit 0
}

export _AGENT_TYPE="$AGENT_TYPE"

python3 << 'PYTHON_EOF'
import json, os, glob


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


def extract_scalar(lines, key):
    """Extract a scalar value from parsed YAML section lines."""
    for line in lines:
        stripped = line.strip().lstrip("- ")
        if stripped.startswith(key + ":"):
            return stripped[len(key) + 1:].strip().strip('"').strip("'")
    return None


def extract_top_level(content, key):
    """Extract a top-level scalar from checkpoint YAML."""
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith(key + ":") and not stripped.startswith("#"):
            indent = len(line) - len(line.lstrip())
            if indent == 0:
                return stripped[len(key) + 1:].strip().strip('"').strip("'")
    return None


agent_type = os.environ.get("_AGENT_TYPE", "unknown")
state_dir = ".claude/workflow-state"
prompts_dir = ".claude/prompts"

# Find latest checkpoint
checkpoints = sorted(glob.glob(os.path.join(state_dir, "*-checkpoint.yaml")))
if not checkpoints:
    print(json.dumps({"additionalContext":
        "[Workflow Context] No checkpoint found — running outside workflow or first phase."}))
    raise SystemExit(0)

try:
    with open(checkpoints[-1]) as f:
        content = f.read()
except Exception:
    print(json.dumps({"additionalContext":
        "[Workflow Context] Checkpoint unreadable — context injection skipped."}))
    raise SystemExit(0)

# Extract scalars
feature = extract_top_level(content, "feature") or "unknown"
complexity = extract_top_level(content, "complexity") or "?"
route = extract_top_level(content, "route") or "?"
phase_completed = extract_top_level(content, "phase_completed") or "?"

# Extract iteration counters
iteration_section = extract_yaml_section(content, "iteration")
plan_review_iter = "0/3"
code_review_iter = "0/3"
if iteration_section:
    plan_review_iter = extract_scalar(iteration_section, "plan_review") or "0/3"
    code_review_iter = extract_scalar(iteration_section, "code_review") or "0/3"

# Determine current iteration for this agent
if agent_type == "plan-reviewer":
    current_iter = plan_review_iter
    review_phase = 2
elif agent_type == "code-reviewer":
    current_iter = code_review_iter
    review_phase = 4
else:
    current_iter = "?/3"
    review_phase = 0

# Find plan and spec artifacts
plans = sorted(glob.glob(os.path.join(prompts_dir, f"{feature}.md")))
plan_path = plans[0] if plans else "not found"
specs = sorted(glob.glob(os.path.join(prompts_dir, f"{feature}-spec.md")))
spec_path = specs[0] if specs else "none"

# Build context header
lines = [
    "[Workflow Context — injected by SubagentStart hook]",
    f"Feature: {feature}",
    f"Complexity: {complexity}",
]

if agent_type == "plan-reviewer":
    lines.append(f"Route: {route}")

lines.append(f"Plan: {plan_path}")
lines.append(f"Spec: {spec_path}")
lines.append(f"Iteration: {current_iter}")

# Code-reviewer specific: verify status
if agent_type == "code-reviewer":
    verify_section = extract_yaml_section(content, "verify_result")
    if verify_section:
        v_status = extract_scalar(verify_section, "status") or "?"
        v_command = extract_scalar(verify_section, "command") or "?"
        lines.append(f"Verify: {v_status} (command: {v_command})")

    # Plan-review approved_with_notes from handoff
    handoff = extract_yaml_section(content, "handoff_payload")
    if handoff:
        notes_section = extract_yaml_section("\n".join(handoff), "approved_with_notes")
        if notes_section:
            lines.append("")
            lines.append("Plan-review notes:")
            for note in notes_section:
                if note.strip():
                    lines.append(f"  {note}")

# Prior iterations from issues_history
issues = extract_yaml_section(content, "issues_history")
if issues:
    entries = []
    current = {}
    for line in issues:
        stripped = line.strip().lstrip("- ")
        if stripped.startswith("phase:"):
            if current:
                entries.append(current)
            current = {"phase": stripped.split(":")[1].strip()}
        elif ":" in stripped and current:
            k, _, v = stripped.partition(":")
            k = k.strip()
            v = v.strip().strip('"').strip("'")
            if k in ("iteration", "verdict", "issues", "resolved"):
                current[k] = v
    if current:
        entries.append(current)

    # Filter to this review phase
    phase_entries = [e for e in entries if e.get("phase") == str(review_phase)]
    if phase_entries:
        lines.append("")
        lines.append("Prior iterations:")
        for entry in phase_entries:
            iter_num = entry.get("iteration", "?")
            verdict = entry.get("verdict", "?")
            issues_str = entry.get("issues", "[]")
            resolved_str = entry.get("resolved", "[]")
            lines.append(f"  - Iteration {iter_num}: {verdict} — issues: {issues_str}")
            if resolved_str and resolved_str != "[]":
                lines.append(f"    Addressed: {resolved_str}")

# Prior verdicts from review-completions.jsonl
completions_file = os.path.join(state_dir, "review-completions.jsonl")
if os.path.isfile(completions_file):
    try:
        with open(completions_file) as f:
            comp_lines = f.readlines()
        relevant = []
        for cl in comp_lines:
            try:
                entry = json.loads(cl.strip())
                if entry.get("agent") == agent_type:
                    relevant.append(entry)
            except (json.JSONDecodeError, KeyError):
                continue
        if relevant:
            lines.append("")
            lines.append("Prior review completions (this pipeline):")
            for r in relevant[-3:]:  # Last 3
                lines.append(f"  - {r.get('completed_at', '?')}: {r.get('verdict', '?')}")
    except Exception:
        pass

text = "\n".join(lines)
print(json.dumps({"additionalContext": text}))
PYTHON_EOF
exit 0
