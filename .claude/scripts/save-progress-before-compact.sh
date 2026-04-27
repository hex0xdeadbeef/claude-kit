#!/bin/bash
# Hook: PreCompact (both matchers: manual, auto — same script, branch on stdin.trigger)
# Purpose:
#   1. ALWAYS (any trigger): save workflow state → additionalContext so it survives compaction
#   2. AUTO trigger only: BLOCK mid-Part Phase 3 compaction (up to MAX_BLOCKS_PER_PART times)
#   3. AUTO trigger only: BLOCK during review iteration if .iteration-in-flight flag exists (P0-04)
#
# Platform: Claude Code v2.1.105 (PreCompact matcher semantics + decision:block)
# Manual trigger is ALWAYS pass-through — user-invoked /compact must never be blocked.
# Safety valve: MAX_BLOCKS_PER_PART prevents context explosion if implementation stalls.
# Safety valve (P0-04): stale .iteration-in-flight (> 30 min mtime) is auto-deleted and not blocked.

set -euo pipefail

INPUT=$(cat)

# python3 required for reliable JSON generation
command -v python3 >/dev/null 2>&1 || {
  echo '{"additionalContext": "PreCompact hook: python3 not available"}'
  exit 0
}

export HOOK_INPUT="$INPUT"
STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-.claude/workflow-state}"

# CWD-independent lib path
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
export LIB_DIR

OUTPUT=$(python3 << 'PYTHON_EOF'
import json, os, glob, time, sys
from datetime import datetime, timezone

# Uniform import fallback (AC-3, KD-6)
try:
    sys.path.insert(0, os.environ['LIB_DIR'])
    from state_render import (
        _extract_yaml_section,
        _extract_scalar,
        load_state,
        render,
        CONTEXT_SIZE_CAP,
    )
except Exception as _import_err:
    print(f'[save-progress-before-compact] WARN: shared state-render unavailable — {_import_err}',
          file=sys.stderr)
    print('{"additionalContext": ""}')
    sys.exit(0)

STATE_DIR = os.environ.get("CLAUDE_WORKFLOW_STATE_DIR", ".claude/workflow-state")
LOG_FILE = os.path.join(STATE_DIR, "hook-log.txt")
BLOCK_STATE_FILE = os.path.join(STATE_DIR, "precompact-block-state.json")
MAX_BLOCKS_PER_PART = 3

# --- REMOVED: extract_yaml_section, extract_scalar definitions (AC-2) ---
# These are now imported from state_render.

# --- UNCHANGED: append_log, load_checkpoint, check_midpart ---
# --- UNCHANGED: load_block_state, save_block_state ---

def append_log(msg):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        with open(LOG_FILE, "a") as f:
            f.write(f"[{ts}] save-progress-before-compact: {msg}\n")
    except Exception:
        pass

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

def check_midpart(content):
    """Return current_part (int > 0) if mid-Part in Phase 3, else None."""
    if not content:
        return None
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
    progress = _extract_yaml_section(content, "implementation_progress")
    if not progress:
        return None
    cp_raw = _extract_scalar(progress, "current_part")
    if not cp_raw:
        return None
    try:
        cp = int(cp_raw)
    except (ValueError, TypeError):
        return None
    return cp if cp > 0 else None

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

def save_block_state(state_dict):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(BLOCK_STATE_FILE, "w") as f:
            json.dump(state_dict, f)
    except Exception:
        pass

# --- CHANGED: build_additional_context now uses render() with checkpoint_ref ---
# PR-003 fix: removed feature/content params — load_state() re-reads from disk.
# Call site updated to match (no args). Double-I/O is acceptable: the checkpoint
# is small (<10 KB) and blocking logic above already read it via load_checkpoint().
def build_additional_context():
    """Build additionalContext string. Uses shared render() for all sections.

    KD-7: checkpoint_ref emits reference-link only (not full YAML body).
    PostCompact hook (verify-state-after-compact.sh) reads checkpoint from disk.
    """
    state = load_state(STATE_DIR, ".claude/prompts")
    return render(state, [
        "handoff_context",
        "issues_history_text",
        "implementation_progress_text",
        "checkpoint_ref",          # KD-7: was f"...{content}" (full body)
        "recent_completions_5",
    ]) or "No workflow state found before compaction."

# --- UNCHANGED: Main decision (mid-Part + iteration-in-flight) ---
feature, content = load_checkpoint()
blocked = False
reason = None
data = {}
try:
    data = json.loads(os.environ.get("HOOK_INPUT", "") or "{}")
except Exception:
    pass
trigger = (data.get("trigger") or "manual").lower()

if trigger == "auto":
    # --- P0-04: Iteration-in-flight check (review cycle running) ---
    # Orchestrator writes .iteration-in-flight before delegating to plan-reviewer/code-reviewer.
    # save-review-checkpoint.sh (SubagentStop) deletes it when the agent truly finishes.
    # Stale safety valve: file older than 30 min is a crash artifact — delete and proceed.
    ITERATION_FILE = os.path.join(STATE_DIR, ".iteration-in-flight")
    if os.path.isfile(ITERATION_FILE):
        try:
            age_seconds = time.time() - os.path.getmtime(ITERATION_FILE)
        except OSError:
            age_seconds = 0
        if age_seconds > 30 * 60:
            try:
                os.remove(ITERATION_FILE)
                append_log("deleted stale .iteration-in-flight (age > 30 min)")
            except OSError:
                pass
        else:
            try:
                with open(ITERATION_FILE) as _f:
                    _info = json.load(_f)
                _agent = _info.get("agent", "review agent")
            except Exception:
                _agent = "review agent"
            blocked = True
            reason = (
                f"Review iteration in progress ({_agent}). Auto-compaction would "
                f"fragment the reviewer's verdict narrative. Wait for the review to "
                f"complete, then /compact manually if needed. Block lifts automatically "
                f"when the review agent stops."
            )
            append_log(f"BLOCKED auto-compact: .iteration-in-flight ({_agent})")
    # --- End P0-04 ---

    # Guard: when iteration-in-flight blocks, skip mid-Part check. The counter-clear
    # else branch is safe to skip here — during review (Phase 2/4) check_midpart returns
    # None anyway, and the (feature, current_part) scoping auto-resets stale state on the
    # next mid-Part event.
    if not blocked:
        current_part = check_midpart(content)
        if current_part is not None:
            state_dict = load_block_state()
            # Reset counter on (feature, current_part) change
            if state_dict.get("feature") != feature or state_dict.get("current_part") != current_part:
                state_dict = {"feature": feature, "current_part": current_part, "block_count": 0}
            if state_dict["block_count"] < MAX_BLOCKS_PER_PART:
                state_dict["block_count"] += 1
                save_block_state(state_dict)
                blocked = True
                reason = (
                    f"Workflow active: Phase 3 Part {current_part}/{feature} in progress. "
                    f"Auto-compaction would discard mid-Part implementation context. "
                    f"Blocked {state_dict['block_count']}/{MAX_BLOCKS_PER_PART} times for this Part. "
                    f"After {MAX_BLOCKS_PER_PART} blocks, compaction will proceed to prevent session failure."
                )
                append_log(
                    f"BLOCKED auto-compact feature={feature} part={current_part} "
                    f"count={state_dict['block_count']}/{MAX_BLOCKS_PER_PART}"
                )
            else:
                append_log(
                    f"PASS auto-compact feature={feature} part={current_part} "
                    f"safety-valve triggered, blocks={state_dict['block_count']}/{MAX_BLOCKS_PER_PART}"
                )
        else:
            # Not mid-Part anymore: clear counter — no longer in a Part that needs protection.
            # Fires on any auto-compact while NOT mid-Part (phase != 2, or current_part == 0,
            # or no checkpoint). Safe to wipe because the counter is only meaningful mid-Part;
            # the next mid-Part event will allocate a fresh (feature, current_part, 0) state.
            state_dict = load_block_state()
            if state_dict.get("feature") is not None:
                save_block_state({"feature": None, "current_part": None, "block_count": 0})

if blocked:
    print(json.dumps({"decision": "block", "reason": reason}))
else:
    print(json.dumps({"additionalContext": build_additional_context()}))
PYTHON_EOF
)

# Size cap — lowered from 40K → 8K (AC-4)
# Note: decision:block output is ~200 bytes — safely under 8K, no special case needed.
CAP=8192
SIZE=${#OUTPUT}
if [[ $SIZE -gt $CAP ]]; then
    mkdir -p "$STATE_DIR"
    OVERFLOW_FILE="${STATE_DIR}/compact-overflow-$(date -u +%s)-$$.log"
    printf '%s' "$OUTPUT" > "$OVERFLOW_FILE"
    echo "[save-progress-before-compact] WARN: output ${SIZE} chars > ${CAP}, saved to ${OVERFLOW_FILE}" >&2
    LIB_DIR="$LIB_DIR" STATE_DIR="$STATE_DIR" python3 -c "
import sys, os; sys.path.insert(0, os.environ['LIB_DIR'])
import state_render; state_render.rotate_spillover_files(os.environ['STATE_DIR'])
"
    PREVIEW=$(printf '%s' "$OUTPUT" | head -c 1000)
    _REF="$OVERFLOW_FILE" _SIZE="$SIZE" _PREVIEW="$PREVIEW" python3 -c "
import json, os
ref = os.environ['_REF']; size = os.environ['_SIZE']; preview = os.environ['_PREVIEW']
print(json.dumps({'additionalContext': '[Overflow] Full output (' + size + ' chars) saved to ' + ref + '. Preview:\n' + preview + '\n…'}))
"
else
    printf '%s\n' "$OUTPUT"
fi
