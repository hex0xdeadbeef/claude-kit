#!/usr/bin/env bash
# Unit-1 (audit #4): PROJECT-KNOWLEDGE.md injection slims to consumed-slot extraction.
# Asserts extract_pk_slots() keeps every reviewer-consumed slot (incl. multi-line block
# scalars + slot-owned comments), drops the dead frontmatter/H1 prefix and non-consumed
# slots, shrinks below the old 4096 prefix, and that the stale "8KB" cap comment is gone.
# Contract-neutral: PK is additionalContext reference data only.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "${ROOT}"
LIB_DIR="${ROOT}/.claude/scripts/lib"
SCRIPT="${ROOT}/.claude/scripts/inject-review-context.sh"
rc=0
fail(){ echo "FAIL: $1"; rc=1; }
pass(){ echo "PASS: $1"; }
has(){ printf '%s' "$1" | grep -q -- "$2"; }       # has HAYSTACK NEEDLE
hasnt(){ ! printf '%s' "$1" | grep -q -- "$2"; }

# ---------- fixture PK: dead prefix + consumed + non-consumed + multi-line slots ----------
FIX="$(mktemp -t pkfix.XXXXXX)"
cat > "${FIX}" <<'PKEOF'
---
pk_schema_version: "1.1.0"
---

# Project Knowledge

<!--
  Dead HTML comment prefix that carries no consumed slot.
-->

**Last Updated:** 2026-01-01

## Language Profile

- LANG_EXT: ".md, .sh, .yaml"
- VERIFY_CMD: "bash .claude/scripts/tests/test-*.sh"
- BUILD_CMD: "bash install.sh"

## Architecture

- LAYER_RULE: |
    orchestrator MARKER_LAYER_CONT flows to reviewers.
    - reviewers run in CLEAN context.

## Domain Purity

- DOMAIN_PROHIBIT: |
    knowledge layer MARKER_DOMAIN_CONT MUST NOT reference workflow-state.

## Error Handling

- ERROR_WRAP: 'echo "[x] <LABEL>: <msg>" >&2'
  # MARKER_ERRWRAP_COMMENT stderr label convention.

## Configuration

- CONFIG_FILE: "config.yaml.example"
PKEOF

# ---------- Part A: hermetic unit test of extract_pk_slots() via lib import ----------
A_OUT="$(LIB_DIR="${LIB_DIR}" FIX="${FIX}" python3 - <<'PY'
import os, sys
sys.path.insert(0, os.environ['LIB_DIR'])
try:
    from pk_slots import extract_pk_slots
except Exception as e:
    print("IMPORT_FAIL:" + str(e)); sys.exit(0)
txt = open(os.environ['FIX']).read()
block = extract_pk_slots(txt)
print("BLOCK_LEN=" + str(len(block)))
print("FIX_LEN=" + str(len(txt)))
sys.stdout.write("====BLOCK====\n" + block + "\n====END====\n")
PY
)"
rm -f "${FIX}"

# AC-1: every consumed slot key present
for slot in LANG_EXT VERIFY_CMD ERROR_WRAP LAYER_RULE DOMAIN_PROHIBIT; do
  if has "${A_OUT}" "${slot}"; then pass "AC-1 slot ${slot} present"; else fail "AC-1 slot ${slot} MISSING"; fi
done
# AC-2: LAYER_RULE multi-line block-scalar continuation survives
if has "${A_OUT}" "MARKER_LAYER_CONT"; then pass "AC-2 LAYER_RULE continuation captured"; else fail "AC-2 LAYER_RULE continuation truncated"; fi
# AC-2b: DOMAIN_PROHIBIT multi-line continuation survives
if has "${A_OUT}" "MARKER_DOMAIN_CONT"; then pass "AC-2b DOMAIN_PROHIBIT continuation captured"; else fail "AC-2b DOMAIN_PROHIBIT continuation truncated"; fi
# AC-2c: ERROR_WRAP slot-owned trailing comment captured (plan-review note)
if has "${A_OUT}" "MARKER_ERRWRAP_COMMENT"; then pass "AC-2c ERROR_WRAP comment captured"; else fail "AC-2c ERROR_WRAP comment dropped"; fi
# AC-3: dead prefix removed (no H1, no frontmatter key)
if hasnt "${A_OUT}" "pk_schema_version"; then pass "AC-3 frontmatter dropped"; else fail "AC-3 frontmatter leaked"; fi
if hasnt "${A_OUT}" "# Project Knowledge"; then pass "AC-3 H1 dropped"; else fail "AC-3 H1 leaked"; fi
# AC-3b: over-capture guard — non-consumed slots excluded
if hasnt "${A_OUT}" "BUILD_CMD"; then pass "AC-3b non-consumed BUILD_CMD excluded"; else fail "AC-3b over-captured BUILD_CMD"; fi
if hasnt "${A_OUT}" "CONFIG_FILE"; then pass "AC-3b non-consumed CONFIG_FILE excluded"; else fail "AC-3b over-captured CONFIG_FILE"; fi
# AC-4: extracted block smaller than the old 4096 prefix and smaller than the file
BL="$(printf '%s' "${A_OUT}" | sed -n 's/^BLOCK_LEN=//p')"
FL="$(printf '%s' "${A_OUT}" | sed -n 's/^FIX_LEN=//p')"
if [ -n "${BL}" ] && [ "${BL}" -gt 0 ] && [ "${BL}" -lt 4096 ]; then pass "AC-4 block ${BL} < 4096"; else fail "AC-4 block size ${BL:-<none>} not < 4096"; fi
if [ -n "${BL}" ] && [ -n "${FL}" ] && [ "${BL}" -lt "${FL}" ]; then pass "AC-4 block ${BL} < fixture ${FL}"; else fail "AC-4 block not smaller than fixture"; fi

# ---------- AC-5: stale "8KB" cap comment removed from the PK region ----------
if grep -q "8KB" "${SCRIPT}"; then fail "AC-5 stale '8KB' comment still present"; else pass "AC-5 stale '8KB' comment removed"; fi
if grep -Eq "CAP|6000" "${SCRIPT}"; then pass "AC-5 real cap referenced"; else fail "AC-5 real cap not referenced"; fi

# ---------- AC-6: no-PK regression branch still fires (untouched telemetry path) ----------
TMP="$(mktemp -d -t pknone.XXXXXX)"; mkdir -p "${TMP}/.claude"
printf 'feature: feat-x\ncomplexity: M\nphase_completed: 4\niteration:\n  plan_review: 1/3\n  code_review: 1/3\n' > "${TMP}/feat-x-checkpoint.yaml"
NO_PK_OUT="$(cd "${TMP}" && echo '{"session_id":"x"}' | CLAUDE_WORKFLOW_STATE_DIR="${TMP}" bash "${SCRIPT}" code-reviewer 2>/dev/null || true)"
rm -rf "${TMP}"
if has "${NO_PK_OUT}" "NOT INJECTED"; then pass "AC-6 no-PK hint branch fires"; else fail "AC-6 no-PK branch regressed"; fi

# ---------- AC-7: integration against the real PK keeps consumed slots, drops H1 ----------
SB="$(mktemp -d -t pkint.XXXXXX)"
printf 'feature: feat-int\ncomplexity: M\nphase_completed: 4\niteration:\n  plan_review: 1/3\n  code_review: 1/3\n' > "${SB}/feat-int-checkpoint.yaml"
INT_JSON="$(echo '{"session_id":"x"}' | CLAUDE_WORKFLOW_STATE_DIR="${SB}" bash "${SCRIPT}" plan-reviewer 2>/dev/null || true)"
rm -rf "${SB}"
INT_CTX="$(printf '%s' "${INT_JSON}" | python3 -c 'import json,sys
d=json.loads(sys.stdin.read() or "{}")
print(d.get("hookSpecificOutput",{}).get("additionalContext",""))' 2>/dev/null || true)"
if has "${INT_CTX}" "Project Knowledge (resolved slots"; then pass "AC-7 real-PK slot block injected"; else fail "AC-7 real-PK slot block missing"; fi
if has "${INT_CTX}" "LAYER_RULE" && has "${INT_CTX}" "VERIFY_CMD"; then pass "AC-7 real consumed slots present"; else fail "AC-7 real consumed slots missing"; fi
if hasnt "${INT_CTX}" "pk_schema_version"; then pass "AC-7 real-PK frontmatter dropped"; else fail "AC-7 real-PK frontmatter leaked"; fi

[ "${rc}" -eq 0 ] && echo "ALL PASS: test-inject-review-context-pk-guard" || echo "SOME FAILED: test-inject-review-context-pk-guard"
exit "${rc}"
