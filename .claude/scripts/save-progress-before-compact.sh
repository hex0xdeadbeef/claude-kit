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
        latest_checkpoint,
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
        # P2: mtime-newest selection (was alphabetical sorted()[-1] — latent bug
        # when feature naming and write order diverge).  Helper returns None on
        # no candidates; existing call sites handle (None, None) sentinel.
        path = latest_checkpoint(STATE_DIR)
        if not path:
            return None, None
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
        "recent_completions_summary",  # P5: per-iter summary (renamed from recent_completions_5)
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

# --- P1 (audit AC-P1.1..7): cooldown on decision:block emission ---
# Rate-limit repeated decision:block emissions to prevent the harness
# from looping auto-compact attempts during long review iterations.
# Protection itself is preserved — the FIRST block per cooldown window
# still fires; only subsequent re-fires within the window are suppressed
# and replaced with informational additionalContext carrying the original
# reason.  Audit ref: .claude/prompts/workflow-hook-loop-audit.md § P1.
def _cooldown_seconds():
    raw = os.environ.get("CLAUDE_PRECOMPACT_COOLDOWN_S", "90")
    try:
        v = int(raw)
    except (ValueError, TypeError):
        v = 90
    if v == 0:
        return 0                # disabled — legacy behaviour
    return v if v >= 30 else 30  # safety floor: never below 30s (AC-P1.11)

COOLDOWN_FILE = os.path.join(STATE_DIR, ".precompact-last-block")
COOLDOWN_SECONDS = _cooldown_seconds()

def _emit_block_with_cooldown(reason_text):
    """Emit decision:block and refresh the cooldown stamp.

    AC-P1.6: on stamp-write failure, log WARN per kit convention and
    emit the block anyway (fail-open — never lose protection due to FS
    error).  The next invocation retries the stamp write.
    """
    try:
        with open(COOLDOWN_FILE, "w") as _cf:
            _cf.write(str(time.time()) + "\n")
    except OSError as _e:
        print(
            f"[save-progress-before-compact] WARN: cooldown-stamp write failed: {_e}",
            file=sys.stderr,
        )
    append_log(f"BLOCKED auto-compact (cooldown stamp refreshed, window={COOLDOWN_SECONDS}s)")
    print(json.dumps({"decision": "block", "reason": reason_text}))

if blocked and COOLDOWN_SECONDS > 0:
    now = time.time()
    last_block_ts = 0.0
    if os.path.isfile(COOLDOWN_FILE):
        try:
            last_block_ts = os.path.getmtime(COOLDOWN_FILE)
        except OSError:
            last_block_ts = 0.0

    # AC-P1.3 backward-compat: if .iteration-in-flight sentinel mtime is
    # STRICTLY newer than the cooldown stamp mtime, treat this as a NEW
    # review session and reset the cooldown.  Same-sentinel re-checks
    # (the loop case) keep cooldown active; distinct sentinels each get
    # their own first block.
    #
    # The plan (PR-001) suggested `>=` as a defence against FS-timestamp
    # coarseness, but a smoke test verified macOS APFS gives sub-second
    # `os.path.getmtime` precision (~100 ms diff observable between two
    # writes 100 ms apart).  With `>=`, equal-mtime cases (which DO
    # occur on rapid in-window re-checks where the previous block wrote
    # the stamp at the same wall-clock second as the original sentinel)
    # would INCORRECTLY reset the cooldown on every loop iteration and
    # defeat the protection.  Strict `>` is therefore correct: only a
    # genuinely-later sentinel (a new orchestrator-write) resets.
    iter_mtime = 0.0
    _iter_file_local = os.path.join(STATE_DIR, ".iteration-in-flight")
    if os.path.isfile(_iter_file_local):
        try:
            iter_mtime = os.path.getmtime(_iter_file_local)
        except OSError:
            iter_mtime = 0.0
    if iter_mtime > last_block_ts:
        last_block_ts = 0.0  # fresh sentinel → reset cooldown

    # Float comparison — int() truncates sub-second deltas to 0 and would
    # incorrectly fall through to the block branch on rapid same-second
    # invocations.  Integer cast is for display only.
    elapsed = (now - last_block_ts) if last_block_ts > 0 else float(COOLDOWN_SECONDS + 1)
    if 0 < elapsed < COOLDOWN_SECONDS:
        # Cooldown active — emit informational additionalContext.
        notice = (
            f"[PreCompact COOLDOWN] {reason} "
            f"(blocked {int(elapsed)}s ago; cooldown {COOLDOWN_SECONDS}s active to prevent block-storm)"
        )
        append_log(f"COOLDOWN_PASS auto-compact (elapsed={int(elapsed)}s, window={COOLDOWN_SECONDS}s)")
        print(json.dumps({"additionalContext": build_additional_context() + "\n\n" + notice}))
    else:
        # Outside cooldown (or stamp absent / sentinel newer) — block + refresh.
        _emit_block_with_cooldown(reason)
elif blocked:
    # CLAUDE_PRECOMPACT_COOLDOWN_S=0 — cooldown disabled, legacy behaviour.
    append_log("BLOCKED auto-compact (cooldown disabled via CLAUDE_PRECOMPACT_COOLDOWN_S=0)")
    print(json.dumps({"decision": "block", "reason": reason}))
else:
    print(json.dumps({"additionalContext": build_additional_context()}))
# --- End P1 cooldown ---
PYTHON_EOF
)

# Size cap — P5: lowered from 8192 → 6000.
# decision:block output is ~200 bytes — safely under 6K, no special case needed.
CAP=6000
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
