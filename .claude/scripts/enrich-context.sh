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
                    if key in ("phase_completed", "phase_name", "complexity", "route", "verdict", "session_type",
                               "file_reads_in_sub_phase", "budget_threshold", "current"):
                        # Note: "current" captures sub_phase.current (sub-phase name like RESEARCH/EVALUATE).
                        # "sub_phase" is NOT extracted — it appears twice in checkpoint YAML
                        # (implementation_progress.sub_phase and sub_phase: section header), causing collision.
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

# 4. Phase-aware exploration loop detection
# Thresholds vary by pipeline phase (from checkpoint) to reduce false positives
# RESEARCH phase (planner): high reads expected → threshold 20
# EVALUATE phase (coder 1.5): moderate reads → threshold 12
# IMPLEMENT phase (coder 2): low reads expected → threshold 5
# Default (no checkpoint / ad-hoc): original threshold 15
try:
    # Determine current phase from checkpoint for threshold selection
    phase_name = ""
    try:
        cp_files = sorted(glob.glob(os.path.join(STATE_DIR, "*-checkpoint.yaml")))
        if cp_files:
            with open(cp_files[-1]) as cpf:
                for cpline in cpf:
                    cpline = cpline.strip()
                    if cpline.startswith("phase_name:"):
                        phase_name = cpline.partition(":")[2].strip().strip('"').strip("'").upper()
                        break
    except Exception:
        pass

    # Phase-aware thresholds (reads in last 20 calls with 0 writes)
    THRESHOLDS = {
        "RESEARCH": 20,     # planner researching — high reads normal
        "EVALUATE": 12,     # coder evaluating plan — moderate reads
        "IMPLEMENT": 5,     # coder implementing — should be writing, not reading
        "PLAN REVIEW": 15,  # reviewer reading plan — moderate reads normal
        "CODE REVIEW": 15,  # reviewer reading code — moderate reads normal
    }
    threshold = THRESHOLDS.get(phase_name, 15)

    transcript = os.path.join(STATE_DIR, "session-transcript.jsonl")
    if os.path.isfile(transcript):
        with open(transcript) as f:
            lines = f.readlines()
        recent = lines[-20:] if len(lines) > 20 else lines
        recent_reads = sum(1 for l in recent if any(t in l for t in ['"tool_name":"Read"', '"tool_name":"Grep"', '"tool_name":"Glob"']))
        recent_writes = sum(1 for l in recent if any(t in l for t in ['"tool_name":"Write"', '"tool_name":"Edit"']))
        if recent_reads > threshold and recent_writes == 0:
            phase_label = phase_name if phase_name else "unknown phase"
            parts.append(
                f"Exploration signal: {recent_reads} reads, {recent_writes} writes in last 20 calls "
                f"(phase: {phase_label}, threshold: {threshold}) — "
                f"consider transitioning to action (see CLAUDE.md)"
            )
except Exception:
    pass

# 4b. Checkpoint-based exploration budget visualization
# More reliable than transcript-based detection (section 4) — reads from checkpoint sub_phase data.
# Budget limits from planner.md (research_budget) and coder.md (evaluate_budget).
try:
    reads_str = data.get("file_reads_in_sub_phase", "") if checkpoints else ""
    if reads_str and reads_str.isdigit():
        reads = int(reads_str)
        sub_phase_name = data.get("current", "unknown").upper()
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
