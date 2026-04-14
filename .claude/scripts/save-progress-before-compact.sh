#!/bin/bash
# Hook: PreCompact (both matchers: manual, auto — same script, branch on stdin.trigger)
# Purpose:
#   1. ALWAYS (any trigger): save workflow state → additionalContext so it survives compaction
#   2. AUTO trigger only: BLOCK mid-Part Phase 3 compaction (up to MAX_BLOCKS_PER_PART times)
#
# Platform: Claude Code v2.1.105 (PreCompact matcher semantics + decision:block)
# Manual trigger is ALWAYS pass-through — user-invoked /compact must never be blocked.
# Safety valve: MAX_BLOCKS_PER_PART prevents context explosion if implementation stalls.

set -euo pipefail

INPUT=$(cat)

# python3 required for reliable JSON generation
command -v python3 >/dev/null 2>&1 || {
  echo '{"additionalContext": "PreCompact hook: python3 not available"}'
  exit 0
}

export HOOK_INPUT="$INPUT"

python3 << 'PYTHON_EOF'
import json, os, glob
from datetime import datetime, timezone

STATE_DIR = ".claude/workflow-state"
LOG_FILE = os.path.join(STATE_DIR, "hook-log.txt")
BLOCK_STATE_FILE = os.path.join(STATE_DIR, "precompact-block-state.json")
MAX_BLOCKS_PER_PART = 3

# --- Parse stdin payload ---
try:
    data = json.loads(os.environ.get("HOOK_INPUT", "") or "{}")
except Exception:
    data = {}
trigger = (data.get("trigger") or "manual").lower()

# --- YAML helpers (same as existing script — don't change semantics) ---
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
    for line in lines:
        s = line.strip().lstrip("- ")
        if s.startswith(key + ":"):
            return s.split(":", 1)[1].strip().strip('"').strip("'")
    return None

def append_log(msg):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        with open(LOG_FILE, "a") as f:
            f.write(f"[{ts}] save-progress-before-compact: {msg}\n")
    except Exception:
        pass

# --- Load latest checkpoint ---
def load_checkpoint():
    try:
        checkpoints = sorted(glob.glob(os.path.join(STATE_DIR, "*-checkpoint.yaml")))
        if not checkpoints:
            return None, None
        path = checkpoints[-1]
        feature = os.path.basename(path).replace("-checkpoint.yaml", "")
        with open(path) as f:
            return feature, f.read()
    except Exception:
        return None, None

# --- Mid-Part detection (auto trigger only) ---
def check_midpart(content):
    """Return current_part (int > 0) if mid-Part in Phase 3, else None."""
    if not content:
        return None
    # phase_completed == 2 required
    pc = None
    for line in content.splitlines():
        s = line.strip()
        if s.startswith("phase_completed:"):
            try:
                pc = int(float(s.split(":", 1)[1].strip().strip('"').strip("'")))
            except (ValueError, TypeError):
                pass
            break
    if pc != 2:
        return None

    progress = extract_yaml_section(content, "implementation_progress")
    if not progress:
        return None

    cp_raw = extract_scalar(progress, "current_part")
    if not cp_raw:
        return None
    try:
        cp = int(cp_raw)
    except (ValueError, TypeError):
        return None

    return cp if cp > 0 else None

# --- Block counter state ---
def load_block_state():
    try:
        if os.path.isfile(BLOCK_STATE_FILE):
            with open(BLOCK_STATE_FILE) as f:
                s = json.load(f)
                if isinstance(s, dict):
                    return s
    except Exception:
        pass
    return {"feature": None, "current_part": None, "block_count": 0}

def save_block_state(state):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(BLOCK_STATE_FILE, "w") as f:
            json.dump(state, f)
    except Exception:
        pass

# --- Build additionalContext (existing behavior preserved verbatim) ---
def build_additional_context(feature, content):
    parts = []
    if content:
        handoff = extract_yaml_section(content, "handoff_payload")
        if handoff:
            parts.append("## Handoff Context\n" + "\n".join(f"  {l}" for l in handoff if l))
        issues = extract_yaml_section(content, "issues_history")
        if issues:
            parts.append("## Issues History\n" + "\n".join(f"  {l}" for l in issues if l))
        progress = extract_yaml_section(content, "implementation_progress")
        if progress:
            parts.append("## Implementation Progress\n" + "\n".join(f"  {l}" for l in progress if l))
        parts.append(f"## Workflow Checkpoint\nFile: {STATE_DIR}/{feature}-checkpoint.yaml\n{content}")
    completions_file = os.path.join(STATE_DIR, "review-completions.jsonl")
    if os.path.isfile(completions_file):
        try:
            with open(completions_file) as f:
                tail = f.readlines()[-5:]
            if tail:
                parts.append("## Recent Review Completions\n" + "".join(tail))
        except Exception:
            pass
    return "\n\n".join(parts) if parts else "No workflow state found before compaction."

# --- Main decision ---
feature, content = load_checkpoint()

blocked = False
reason = None

if trigger == "auto":
    current_part = check_midpart(content)
    if current_part is not None:
        state = load_block_state()
        # Reset counter on (feature, current_part) change
        if state.get("feature") != feature or state.get("current_part") != current_part:
            state = {"feature": feature, "current_part": current_part, "block_count": 0}
        if state["block_count"] < MAX_BLOCKS_PER_PART:
            state["block_count"] += 1
            save_block_state(state)
            blocked = True
            reason = (
                f"Workflow active: Phase 3 Part {current_part}/{feature} in progress. "
                f"Auto-compaction would discard mid-Part implementation context. "
                f"Blocked {state['block_count']}/{MAX_BLOCKS_PER_PART} times for this Part. "
                f"After {MAX_BLOCKS_PER_PART} blocks, compaction will proceed to prevent session failure."
            )
            append_log(
                f"BLOCKED auto-compact feature={feature} part={current_part} "
                f"count={state['block_count']}/{MAX_BLOCKS_PER_PART}"
            )
        else:
            append_log(
                f"PASS auto-compact feature={feature} part={current_part} "
                f"safety-valve triggered, blocks={state['block_count']}/{MAX_BLOCKS_PER_PART}"
            )
    else:
        # Not mid-Part anymore: clear counter — no longer in a Part that needs protection.
        # Fires on any auto-compact while NOT mid-Part (phase != 2, or current_part == 0,
        # or no checkpoint). Safe to wipe because the counter is only meaningful mid-Part;
        # the next mid-Part event will allocate a fresh (feature, current_part, 0) state.
        state = load_block_state()
        if state.get("feature") is not None:
            save_block_state({"feature": None, "current_part": None, "block_count": 0})

# --- Emit output ---
if blocked:
    print(json.dumps({"decision": "block", "reason": reason}))
else:
    print(json.dumps({"additionalContext": build_additional_context(feature, content)}))
PYTHON_EOF
