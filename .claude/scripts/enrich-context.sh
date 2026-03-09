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
                    if key in ("phase_completed", "phase_name", "complexity", "route", "verdict"):
                        data[key] = val

        phase = data.get("phase_name", "unknown")
        phase_num = data.get("phase_completed", "?")
        complexity = data.get("complexity", "?")
        route = data.get("route", "?")
        verdict = data.get("verdict", "null")

        parts.append(f"Checkpoint: {feature} | Phase: {phase} ({phase_num}/4) | Complexity: {complexity} | Route: {route} | Verdict: {verdict}")
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

# 4. Git branch (fast, subprocess)
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
