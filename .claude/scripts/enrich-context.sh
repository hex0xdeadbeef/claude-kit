#!/bin/bash
# Hook: UserPromptSubmit (no matcher — fires on every prompt)
# Purpose: Enrich prompt with current workflow state
# Output: {"additionalContext": "..."} — compact workflow state summary
# Non-blocking: ALWAYS exit 0 (never block user's prompt)
# Performance target: < 500ms

set -euo pipefail

# Drain stdin — hook contract sends JSON on stdin, must consume it
# to prevent broken pipe errors before python3 takes over
INPUT=$(cat)

# Graceful degradation: no python3 → empty context
command -v python3 >/dev/null 2>&1 || exit 0

python3 << 'PYTHON_EOF'
import json, os, glob, subprocess, sys

STATE_DIR = ".claude/workflow-state"
PROMPTS_DIR = ".claude/prompts"

parts = []

# 1. Checkpoint state (highest priority)
try:
    checkpoints = sorted(glob.glob(os.path.join(STATE_DIR, "*-checkpoint.yaml")))
    if checkpoints:
        latest = checkpoints[-1]
        feature = os.path.basename(latest).replace("-checkpoint.yaml", "")

        # Parse YAML manually (no pyyaml dependency)
        data = {}
        with open(latest) as f:
            for line in f:
                line = line.strip()
                if ":" in line and not line.startswith("-") and not line.startswith("#"):
                    key, _, val = line.partition(":")
                    key = key.strip()
                    val = val.strip().strip('"').strip("'")
                    # Remap "current" → "sub_phase_current" to avoid collision with
                    # any future top-level "current" key in checkpoint schema.
                    # "sub_phase" itself is NOT extracted — it appears twice in checkpoint YAML
                    # (implementation_progress.sub_phase and sub_phase: section header).
                    if key == "current":
                        data["sub_phase_current"] = val
                    elif key in ("phase_completed", "phase_name", "complexity", "route", "verdict", "session_type",
                                 "file_reads_in_sub_phase", "budget_threshold"):
                        data[key] = val

        phase = data.get("phase_name", "unknown")
        phase_num = data.get("phase_completed", "?")
        complexity = data.get("complexity", "?")
        route = data.get("route", "?")
        verdict = data.get("verdict", "null")
        session_type = data.get("session_type", "ad-hoc")

        parts.append(f"Checkpoint: {feature} | Phase: {phase} ({phase_num}/4) | Complexity: {complexity} | Route: {route} | Verdict: {verdict} | Session: {session_type}")
except Exception:
    pass

# 2. Available plans
try:
    plans = sorted(glob.glob(os.path.join(PROMPTS_DIR, "*.md")))
    plan_names = [os.path.basename(p) for p in plans if not p.endswith("-evaluate.md")]
    if plan_names:
        parts.append(f"Plans: {', '.join(plan_names)}")
except Exception:
    pass

# 3. Recent review completions (last 3)
try:
    completions_file = os.path.join(STATE_DIR, "review-completions.jsonl")
    if os.path.isfile(completions_file):
        with open(completions_file) as f:
            lines = f.readlines()
        recent = lines[-3:] if len(lines) > 3 else lines
        reviews = []
        for line in recent:
            try:
                entry = json.loads(line.strip())
                agent = entry.get("agent", "unknown")
                ts = entry.get("completed_at", "?")
                reviews.append(f"{agent} @ {ts}")
            except json.JSONDecodeError:
                print("Warning: malformed JSONL line in review-completions", file=sys.stderr)
        if reviews:
            parts.append(f"Recent reviews: {'; '.join(reviews)}")
except Exception:
    pass

# 4. Checkpoint-based exploration budget visualization
# Reads from checkpoint sub_phase data to show exploration budget usage.
# Budget limits from planner.md (research_budget) and coder.md (evaluate_budget).
try:
    reads_str = data.get("file_reads_in_sub_phase", "") if checkpoints else ""
    if reads_str and reads_str.isdigit():
        reads = int(reads_str)
        sub_phase_name = data.get("sub_phase_current", "unknown").upper()
        cp_complexity = data.get("complexity", "M").upper()
        cp_phase = data.get("phase_name", "").lower()

        # Budget limits: (phase_name, complexity) → read limit
        # Source: planner.md research_budget, coder.md evaluate_budget
        BUDGET_LIMITS = {
            ("planning", "S"): 5,   ("planning", "M"): 10,
            ("planning", "L"): 20,  ("planning", "XL"): 30,
            ("implementation", "S"): 3,  ("implementation", "M"): 6,
            ("implementation", "L"): 12, ("implementation", "XL"): 18,
        }

        # Priority: checkpoint budget_threshold > phase/complexity lookup > default 20
        cp_threshold = data.get("budget_threshold", "")
        if cp_threshold and cp_threshold.isdigit():
            limit = int(cp_threshold)
        else:
            limit = BUDGET_LIMITS.get((cp_phase, cp_complexity), 20)

        if limit > 0:
            pct = min(int(reads / limit * 100), 999)
            budget_line = f"Budget: {reads}/{limit} ({pct}%) — {sub_phase_name}"
            if pct > 80:
                budget_line += " — consider transitioning"
            parts.append(budget_line)
except Exception:
    pass

# 5. Git branch (fast, subprocess)
try:
    result = subprocess.run(
        ["git", "branch", "--show-current"],
        capture_output=True, text=True, timeout=2
    )
    branch = result.stdout.strip()
    if branch:
        parts.append(f"Branch: {branch}")
except Exception:
    pass

# Output — wrapped in try-except to guarantee valid JSON even on edge cases
try:
    if parts:
        context = "[Workflow State]\n" + "\n".join(parts)
        print(json.dumps({"additionalContext": context}))
    else:
        # No state — empty context, no noise
        print(json.dumps({"additionalContext": ""}))
except Exception:
    # Fallback: always output valid JSON
    print('{"additionalContext": ""}')

PYTHON_EOF

# ALWAYS exit 0 — never block user's prompt
exit 0
