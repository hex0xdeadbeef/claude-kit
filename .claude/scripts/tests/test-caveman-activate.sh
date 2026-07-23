#!/usr/bin/env bash
# test-caveman-activate.sh — smoke tests for caveman-activate.sh
# Pattern: mirrors test-validate-handoff.sh (sandboxed STATE_DIR, env-unset isolation).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/../caveman-activate.sh"

TMP_DIR="$(mktemp -d -t caveman-activate-tests.XXXXXX)"
export CLAUDE_WORKFLOW_STATE_DIR="${TMP_DIR}"
trap 'rm -rf "${TMP_DIR}"' EXIT

PASS=0
FAIL=0

unset_envs() {
  unset CLAUDE_CAVEMAN_MODE
}

# ─── Test 1: default mode = lite when env unset and no flag ─────────────────────
unset_envs
out_t1=$(echo '' | bash "${HOOK}" 2>/dev/null || true)
if echo "${out_t1}" | grep -q '"additionalContext"' \
   && echo "${out_t1}" | grep -q '\[CAVEMAN MODE: lite\]' \
   && [[ -f "${TMP_DIR}/.caveman-mode" ]] \
   && [[ "$(cat "${TMP_DIR}/.caveman-mode")" == "lite" ]]; then
  echo "  PASS: T1 default mode = lite, flag written"
  PASS=$((PASS + 1))
else
  echo "  FAIL: T1 default mode = lite"
  FAIL=$((FAIL + 1))
fi
rm -f "${TMP_DIR}/.caveman-mode"

# ─── Test 2: env override = off ─ silent exit, no flag write ────────────────────
unset_envs
export CLAUDE_CAVEMAN_MODE="off"
out_t2=$(echo '' | bash "${HOOK}" 2>/dev/null || true)
if [[ -z "${out_t2}" ]] && [[ ! -f "${TMP_DIR}/.caveman-mode" ]]; then
  echo "  PASS: T2 off-mode silent exit, no flag"
  PASS=$((PASS + 1))
else
  echo "  FAIL: T2 off-mode (got: '${out_t2}')"
  FAIL=$((FAIL + 1))
fi
unset CLAUDE_CAVEMAN_MODE

# ─── Test 3: env override = lite ────────────────────────────────────────────────
export CLAUDE_CAVEMAN_MODE="lite"
out_t3=$(echo '' | bash "${HOOK}" 2>/dev/null || true)
if echo "${out_t3}" | grep -q '\[CAVEMAN MODE: lite\]' \
   && [[ "$(cat "${TMP_DIR}/.caveman-mode")" == "lite" ]]; then
  echo "  PASS: T3 env=lite explicit"
  PASS=$((PASS + 1))
else
  echo "  FAIL: T3 env=lite explicit"
  FAIL=$((FAIL + 1))
fi
rm -f "${TMP_DIR}/.caveman-mode"
unset CLAUDE_CAVEMAN_MODE

# ─── Test 4: invalid mode → WARN + fallback to lite ──────────
# Single hook invocation captures both streams; greps split them by prefix.
export CLAUDE_CAVEMAN_MODE="ultra"
out_and_err=$(echo '' | bash "${HOOK}" 2>&1)
out_t4=$(echo "${out_and_err}" | grep -v '^\[caveman-activate\]' || true)
warn_t4=$(echo "${out_and_err}" | grep '^\[caveman-activate\]' || true)
if echo "${warn_t4}" | grep -qE '^\[caveman-activate\] WARN: invalid mode' \
   && echo "${out_t4}" | grep -q '\[CAVEMAN MODE: lite\]'; then
  echo "  PASS: T4 invalid mode WARN + fallback"
  PASS=$((PASS + 1))
else
  echo "  FAIL: T4 invalid mode (warn: '${warn_t4:0:120}', out: '${out_t4:0:120}')"
  FAIL=$((FAIL + 1))
fi
rm -f "${TMP_DIR}/.caveman-mode"
unset CLAUDE_CAVEMAN_MODE

# ─── Test 5: sandbox env honored — assert real flag mtime unchanged ──
# Portable mtime: Darwin uses `stat -f '%m'`, Linux uses `stat -c '%Y'`. Try both.
unset_envs
REPO_FLAG="$(cd "${SCRIPT_DIR}/../../.." && pwd)/.claude/workflow-state/.caveman-mode"
if [[ -e "${REPO_FLAG}" ]]; then
  mtime_before=$(stat -f '%m' "${REPO_FLAG}" 2>/dev/null || stat -c '%Y' "${REPO_FLAG}" 2>/dev/null || echo "unknown")
else
  mtime_before="absent"
fi
echo '' | bash "${HOOK}" >/dev/null 2>&1 || true
if [[ -e "${REPO_FLAG}" ]]; then
  mtime_after=$(stat -f '%m' "${REPO_FLAG}" 2>/dev/null || stat -c '%Y' "${REPO_FLAG}" 2>/dev/null || echo "unknown")
else
  mtime_after="absent"
fi
if [[ "${mtime_before}" == "${mtime_after}" ]] && [[ -f "${TMP_DIR}/.caveman-mode" ]]; then
  echo "  PASS: T5 sandbox env honored (real flag mtime unchanged)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: T5 sandbox env (mtime before='${mtime_before}', after='${mtime_after}', sandbox-exists=$([[ -f "${TMP_DIR}/.caveman-mode" ]] && echo yes || echo no))"
  FAIL=$((FAIL + 1))
fi
rm -f "${TMP_DIR}/.caveman-mode"

# ─── Test 6: atomic write — flag content always valid (never partial) ──
# Use `loop_failed` flag so ONE FAIL does not double-count with a PASS.
unset_envs
loop_failed=0
for i in 1 2 3 4 5; do
  echo '' | bash "${HOOK}" >/dev/null 2>&1 || true
  content=$(cat "${TMP_DIR}/.caveman-mode" 2>/dev/null || echo "<missing>")
  if [[ "${content}" != "lite" ]]; then
    echo "  FAIL: T6 atomic write — iter ${i} got '${content}'"
    FAIL=$((FAIL + 1))
    loop_failed=1
    break
  fi
done
if [[ "${loop_failed}" -eq 0 ]]; then
  echo "  PASS: T6 atomic write (5x consistent)"
  PASS=$((PASS + 1))
fi

echo "─── caveman-activate.sh: ${PASS} passed, ${FAIL} failed ───"
[[ "${FAIL}" -eq 0 ]]
