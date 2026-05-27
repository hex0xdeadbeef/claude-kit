#!/usr/bin/env bash
# test-stop-block-cap-invariant.sh — I-02: the kit's Stop-block circuit breaker
# (STOP_BLOCK_MAX in check-uncommitted.sh) MUST stay below the platform stop-hook
# block cap (CLAUDE_CODE_STOP_HOOK_BLOCK_CAP, default 8 since Claude Code v2.1.143),
# so our breaker fires first and saves state before the platform force-ends the turn.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOK="${SCRIPT_DIR}/../check-uncommitted.sh"
PASS=0; FAIL=0
echo "=== test-stop-block-cap-invariant.sh ==="

# 1. STOP_BLOCK_MAX is a numeric script constant
VAL="$(grep -E '^STOP_BLOCK_MAX=[0-9]+' "$HOOK" | head -n1 | sed -E 's/^STOP_BLOCK_MAX=([0-9]+).*/\1/')"
if [[ -n "$VAL" && "$VAL" =~ ^[0-9]+$ ]]; then
  echo "  PASS: STOP_BLOCK_MAX is numeric ($VAL)"; PASS=$((PASS+1))
else
  echo "  FAIL: STOP_BLOCK_MAX not found / non-numeric"; FAIL=$((FAIL+1)); VAL=999
fi

# 2. Invariant: STOP_BLOCK_MAX < 8 (platform default cap)
if [[ "$VAL" -lt 8 ]]; then
  echo "  PASS: STOP_BLOCK_MAX ($VAL) < platform default 8"; PASS=$((PASS+1))
else
  echo "  FAIL: STOP_BLOCK_MAX ($VAL) >= 8 — breaker would not fire before platform force-end"; FAIL=$((FAIL+1))
fi

# 3. check-uncommitted.sh carries an invariant comment naming the platform cap var
if grep -Fq 'CLAUDE_CODE_STOP_HOOK_BLOCK_CAP' "$HOOK"; then
  echo "  PASS: check-uncommitted.sh comment references CLAUDE_CODE_STOP_HOOK_BLOCK_CAP"; PASS=$((PASS+1))
else
  echo "  FAIL: no invariant comment referencing CLAUDE_CODE_STOP_HOOK_BLOCK_CAP"; FAIL=$((FAIL+1))
fi

# 4. CLAUDE.md documents the 5<8 interaction (AC-2.2)
if grep -Fq 'CLAUDE_CODE_STOP_HOOK_BLOCK_CAP' "${ROOT}/CLAUDE.md"; then
  echo "  PASS: CLAUDE.md documents the platform-cap interaction"; PASS=$((PASS+1))
else
  echo "  FAIL: CLAUDE.md missing CLAUDE_CODE_STOP_HOOK_BLOCK_CAP note"; FAIL=$((FAIL+1))
fi

echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
