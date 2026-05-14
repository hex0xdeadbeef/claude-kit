#!/usr/bin/env bash
# Part 3 / AD-1: lib/log.sh log_stderr function emits the additive prefix
# [<basename>][session=<short-sid>][eff=<level>] LABEL: <message>
# Degrades to "unknown" placeholders when CLAUDE_CODE_SESSION_ID / CLAUDE_EFFORT absent.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
LIB="${REPO_ROOT}/.claude/scripts/lib/log.sh"
test -f "${LIB}" || { echo "[test-log-stderr-prefix] FAIL: ${LIB} missing" >&2; exit 1; }

# Case 1: both env set
out=$(CLAUDE_CODE_SESSION_ID="0123456789abcdef0000000000000000" CLAUDE_EFFORT="high" \
  bash -c 'source "$1"; log_stderr INFO "smoke test"' _ "${LIB}" 2>&1)
echo "${out}" | grep -qE '\[session=01234567\]' \
  || { echo "[test-log-stderr-prefix] FAIL: session tag missing/wrong" >&2; echo "got: ${out}" >&2; exit 1; }
echo "${out}" | grep -qE '\[eff=high\]' \
  || { echo "[test-log-stderr-prefix] FAIL: eff tag missing" >&2; exit 1; }
echo "${out}" | grep -qE 'INFO: smoke test' \
  || { echo "[test-log-stderr-prefix] FAIL: trailing LABEL: msg missing" >&2; exit 1; }

# Case 2: env unset → "unknown"
out=$(env -i HOME="${HOME:-/tmp}" PATH="${PATH}" \
  bash -c 'source "$1"; log_stderr WARN "missing env"' _ "${LIB}" 2>&1)
echo "${out}" | grep -qE '\[session=unknown\]' \
  || { echo "[test-log-stderr-prefix] FAIL: expected session=unknown" >&2; echo "got: ${out}" >&2; exit 1; }
echo "${out}" | grep -qE '\[eff=unknown\]' \
  || { echo "[test-log-stderr-prefix] FAIL: expected eff=unknown" >&2; exit 1; }

# Case 3: logger does NOT crash the caller
ec=0
bash -c 'source "$1"; log_stderr ERROR "x"; echo "post"' _ "${LIB}" >/dev/null 2>&1 || ec=$?
test "${ec}" -eq 0 || { echo "[test-log-stderr-prefix] FAIL: caller exited non-zero (${ec})" >&2; exit 1; }

echo "[test-log-stderr-prefix] PASS"
