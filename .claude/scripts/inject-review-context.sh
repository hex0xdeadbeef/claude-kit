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

# Read SubagentStart payload — need session_id for IMP-02 filtering
HOOK_INPUT=$(cat 2>/dev/null || echo '{}')
export _HOOK_INPUT="$HOOK_INPUT"

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


def aggregate_pipeline_metrics(metrics_file, complexity, agent_type):
    """Read pipeline-metrics.jsonl and return a brief history summary, or None.

    Returns None when:
    - File missing or unreadable
    - Fewer than 3 total entries (insufficient history)
    """
    if not os.path.isfile(metrics_file):
        return None
    try:
        entries = []
        with open(metrics_file) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        entries.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
    except Exception:
        return None

    if len(entries) < 3:
        return None

    # Iterations for matching complexity
    matching = [e for e in entries if e.get("complexity", {}).get("estimated") == complexity
                or e.get("complexity", {}).get("actual") == complexity]
    if not matching:
        matching = entries  # Fall back to all runs if no complexity match

    if agent_type == "plan-reviewer":
        iters = [e.get("review_iterations", {}).get("plan_review", 0) for e in matching if "review_iterations" in e]
    else:
        iters = [e.get("review_iterations", {}).get("code_review", 0) for e in matching if "review_iterations" in e]
    avg_iters = round(sum(iters) / len(iters), 1) if iters else None

    # Top issue categories across all entries
    category_counts = {}
    for e in entries:
        found = e.get("issues_found", {})
        for cat, count in found.items():
            if isinstance(count, int) and count > 0:
                category_counts[cat] = category_counts.get(cat, 0) + count
    top_categories = sorted(category_counts.items(), key=lambda x: x[1], reverse=True)[:3]

    # Anomaly: recent BLOCKER pattern (last 3 runs)
    recent = entries[-3:]
    recent_blockers = sum(1 for e in recent if e.get("issues_found", {}).get("blocker", 0) > 0)

    lines = ["[Pipeline history context]:"]
    n_complexity = len(matching)
    n_total = len(entries)
    scope = f"{complexity} complexity" if n_complexity < n_total else "all runs"
    if avg_iters is not None:
        review_label = "plan-review" if agent_type == "plan-reviewer" else "code-review"
        lines.append(f"- Avg {review_label} iterations ({scope}, {n_complexity} runs): {avg_iters}")
    if top_categories:
        cats = ", ".join(f"{cat} ({cnt})" for cat, cnt in top_categories)
        lines.append(f"- Top issue categories: {cats}")
    if recent_blockers >= 2:
        lines.append(f"- Note: {recent_blockers}/3 recent runs had BLOCKER issues — focus security/architecture checks")

    return "\n".join(lines) if len(lines) > 1 else None

agent_type = os.environ.get("_AGENT_TYPE", "unknown")

# IMP-02: session_id from SubagentStart payload for filtering review-completions
try:
    _payload = json.loads(os.environ.get("_HOOK_INPUT", "{}"))
    current_session_id = _payload.get("session_id", "")
except Exception:
    current_session_id = ""

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
        # Collect list items after "approved_with_notes:" key
        # (extract_yaml_section strips indentation, so use list-item collector)
        in_notes = False
        notes = []
        for h_line in handoff:
            stripped = h_line.strip()
            if stripped.startswith("approved_with_notes:"):
                in_notes = True
                continue
            if in_notes:
                if stripped.startswith("- "):
                    notes.append(stripped[2:].strip().strip('"').strip("'"))
                elif stripped and not stripped.startswith("-"):
                    break
        if notes:
            lines.append("")
            lines.append("Plan-review notes:")
            for note in notes:
                lines.append(f"  - {note}")

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

# Prior verdicts from review-completions.jsonl (IMP-02: filter by session + effective_agent_type)
# P1-3: Preserve "unknown" entries as failed_attempts metadata for orchestrator recovery decisions
# P3-3: Read from both primary and fallback locations — fallback written by IMP-06 when primary fails
completions_file = os.path.join(state_dir, "review-completions.jsonl")
fallback_file = os.path.join("/tmp", "claude-review-completions-fallback.jsonl")

comp_lines = []
for _cf in (completions_file, fallback_file):
    if os.path.isfile(_cf):
        try:
            with open(_cf) as f:
                comp_lines.extend(f.readlines())
        except Exception:
            pass

if comp_lines:
    try:
        relevant = []
        failed_attempts = []
        seen = set()  # P3-3: deduplicate by (session_id, completed_at, agent)
        for cl in comp_lines:
            try:
                entry = json.loads(cl.strip())
            except json.JSONDecodeError:
                continue
            # P3-3: deduplicate entries that exist in both primary and fallback
            dedup_key = (entry.get("session_id", ""), entry.get("completed_at", ""), entry.get("agent", ""))
            if dedup_key in seen:
                continue
            seen.add(dedup_key)
            # IMP-02: scope to current session only
            if current_session_id and entry.get("session_id") != current_session_id:
                continue
            # IMP-05: prefer effective_agent_type, fall back to raw agent for legacy entries
            eff = entry.get("effective_agent_type") or entry.get("agent", "")
            # P1-3: Track unknown entries as failed attempts instead of discarding
            if eff == "unknown":
                failed_attempts.append(entry)
                continue
            if eff != agent_type:
                continue
            relevant.append(entry)
        if relevant:
            lines.append("")
            lines.append("Prior review completions (this pipeline):")
            for r in relevant[-3:]:  # Last 3
                lines.append(f"  - {r.get('completed_at', '?')}: {r.get('verdict', '?')}")
        if failed_attempts:
            lines.append(f"Prior failed attempts (unknown agent_type): {len(failed_attempts)}")
            lines.append(f"  Last failed at: {failed_attempts[-1].get('completed_at', '?')}")
    except Exception:
        pass


# Pipeline history (IMP-F) — inject only if sufficient history exists
metrics_summary = aggregate_pipeline_metrics(
    os.path.join(state_dir, "pipeline-metrics.jsonl"),
    complexity,
    agent_type
)
if metrics_summary:
    lines.append("")
    lines.append(metrics_summary)

text = "\n".join(lines)
print(json.dumps({"additionalContext": text}))
PYTHON_EOF
exit 0
