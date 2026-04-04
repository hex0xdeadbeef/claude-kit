#!/bin/bash
# Hook: PostCompact
# Purpose: Verify workflow state integrity after compaction, re-inject critical state if needed
# Non-blocking: exit 0 always
#
# Checks:
#   1. Checkpoint file exists and is readable
#   2. review-completions.jsonl is valid JSONL (each line parses as JSON)
#   3. Re-injects key state fields (phase, iteration, feature, handoff, issues history,
#      implementation progress) as additionalContext so the model has them even if
#      PreCompact additionalContext was truncated
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
            # Extract key scalar fields
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

            # Extract handoff context
            handoff = extract_yaml_section(content, "handoff_payload")
            if handoff:
                h_to = extract_scalar(handoff, "to")
                h_artifact = extract_scalar(handoff, "artifact")
                h_verdict = extract_scalar(handoff, "verdict")
                if any([h_to, h_artifact, h_verdict]):
                    state_summary.append(f"  handoff: to={h_to or '?'}, "
                                         f"artifact={h_artifact or '?'}, "
                                         f"verdict={h_verdict or '?'}")

            # Extract issues history (count iterations and last verdict)
            issues = extract_yaml_section(content, "issues_history")
            if issues:
                iter_entries = []
                current = {}
                for line in issues:
                    stripped = line.strip().lstrip("- ")
                    if stripped.startswith("phase:"):
                        if current:
                            iter_entries.append(current)
                        current = {"phase": stripped.split(":")[1].strip()}
                    elif ":" in stripped and current:
                        k, _, v = stripped.partition(":")
                        k = k.strip()
                        v = v.strip().strip('"').strip("'")
                        if k in ("iteration", "verdict"):
                            current[k] = v
                if current:
                    iter_entries.append(current)
                for entry in iter_entries:
                    state_summary.append(
                        f"  history: phase {entry.get('phase', '?')} "
                        f"iter {entry.get('iteration', '?')} -> {entry.get('verdict', '?')}")

            # Extract implementation progress
            progress = extract_yaml_section(content, "implementation_progress")
            if progress:
                p_completed = extract_scalar(progress, "parts_completed")
                p_total = extract_scalar(progress, "parts_total")
                p_current = extract_scalar(progress, "current_part")
                p_sub = extract_scalar(progress, "sub_phase")
                if any([p_completed, p_total, p_sub]):
                    state_summary.append(
                        f"  progress: parts {p_completed or '?'}/{p_total or '?'}, "
                        f"current={p_current or '?'}, sub_phase={p_sub or '?'}")

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
