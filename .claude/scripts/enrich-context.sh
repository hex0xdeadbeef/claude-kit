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

# CWD-independent lib path — works regardless of invocation directory
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
export LIB_DIR

STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-.claude/workflow-state}"

OUTPUT=$(python3 << 'PYTHON_EOF'
import json, os, glob, subprocess, sys, hashlib

# Uniform import fallback (AC-3, KD-6)
try:
    sys.path.insert(0, os.environ['LIB_DIR'])
    import state_render
except Exception as _import_err:
    print(f'[enrich-context] WARN: shared state-render unavailable — {_import_err}',
          file=sys.stderr)
    print('{"additionalContext": ""}')
    sys.exit(0)

STATE_DIR = os.environ.get("CLAUDE_WORKFLOW_STATE_DIR", ".claude/workflow-state")
PROMPTS_DIR = ".claude/prompts"
HASH_FILE = os.path.join(STATE_DIR, ".enrich-last-hash")

parts = []
session_title = None

# Hash-guard: skip re-injection if checkpoint content unchanged since last run.
# VERBATIM from IMP-03 (commit 39a4893) — must not change for AC-10.
_checkpoint_hash = None
_checkpoints_pre = sorted(glob.glob(os.path.join(STATE_DIR, "*-checkpoint.yaml")))
if _checkpoints_pre:
    _latest_pre = _checkpoints_pre[-1]
    try:
        with open(_latest_pre, 'rb') as _f:
            _cp_bytes = _f.read()
        _checkpoint_hash = hashlib.sha256(_cp_bytes).hexdigest()
        try:
            with open(HASH_FILE) as _hf:
                _stored_hash = _hf.read().strip()
        except FileNotFoundError:
            _stored_hash = None
        if _stored_hash == _checkpoint_hash:
            sys.exit(0)
    except Exception:
        _checkpoint_hash = None

# Load state via shared module
state = state_render.load_state(STATE_DIR, PROMPTS_DIR)

# 1. Checkpoint one-liner + sessionTitle (IMP-2)
try:
    oneliner = state_render.render(state, ["checkpoint_oneliner"])
    if oneliner:
        parts.append(oneliner)
        feature = state.get("feature")
        complexity = state.get("complexity", "?")
        phase_num = state.get("phase_completed", "?")
        if feature and complexity and complexity != "?":
            try:
                cur_phase = min(int(float(phase_num)) + 1, 5) if phase_num not in ("?", "") else 1
            except (ValueError, TypeError):
                cur_phase = 1
            session_title = f"[WF] {feature[:40]} | Ph{cur_phase}/5 | {complexity}"
        # Cache-hint warn for L/XL without 1H TTL
        if complexity in ("L", "XL") and not os.environ.get("ENABLE_PROMPT_CACHING_1H"):
            print(
                "[enrich-context] WARN: L/XL task detected but ENABLE_PROMPT_CACHING_1H not set. "
                "Expected cache-miss rate ~50% at phase boundaries. "
                "See CLAUDE.md > Prompt Cache Policy.",
                file=sys.stderr
            )
except Exception:
    pass

# 2–5. Remaining sections
for _section in ["plans", "review_completions_brief", "budget", "branch"]:
    try:
        result = state_render.render(state, [_section])
        if result:
            parts.append(result)
    except Exception:
        pass

# Output (IMP-2: nested hookSpecificOutput when session_title set)
try:
    context = "[Workflow State]\n" + "\n".join(parts) if parts else ""
    if session_title:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": context,
                "sessionTitle": session_title,
            }
        }))
    else:
        print(json.dumps({"additionalContext": context}))
    # Hash write ONLY after successful emission (IMP-03 invariant)
    if _checkpoint_hash:
        try:
            with open(HASH_FILE, 'w') as _hf:
                _hf.write(_checkpoint_hash + '\n')
        except Exception:
            pass
except Exception:
    print('{"additionalContext": ""}')

PYTHON_EOF
)

# Size cap — P5: lowered 8192 → 6000 (keeps in sync with state_render.CONTEXT_SIZE_CAP)
CAP=6000
SIZE=${#OUTPUT}
if [[ $SIZE -gt $CAP ]]; then
    mkdir -p "$STATE_DIR"
    OVERFLOW_FILE="${STATE_DIR}/compact-overflow-$(date -u +%s)-$$.log"
    printf '%s' "$OUTPUT" > "$OVERFLOW_FILE"
    echo "[enrich-context] WARN: output ${SIZE} chars > ${CAP}, saved to ${OVERFLOW_FILE}" >&2
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

# ALWAYS exit 0 — never block user's prompt
exit 0
