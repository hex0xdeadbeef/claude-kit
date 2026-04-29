#!/usr/bin/env bash
# test-jsonl-append-race.sh
# P4 — JSONL append race test
#
# Asserts:
#   1. CLAUDE_JSONL_APPEND_LOCK=on: 4 concurrent appenders preserve all 4 well-formed JSONL lines
#   2. CLAUDE_JSONL_APPEND_LOCK unset/off: behaviour byte-identical to legacy direct append
#   3. Python helper jsonl_lock.py exposes the same contract
#
# Convention: exit 0 on success, exit 1 on assertion failure.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SANDBOX="$(mktemp -d -t jsonl-race-XXXXXX)"
trap 'rm -rf "${SANDBOX}"' EXIT

export CLAUDE_WORKFLOW_STATE_DIR="${SANDBOX}"
mkdir -p "${SANDBOX}"

LIB_BASH="${REPO_ROOT}/.claude/scripts/lib/jsonl-lock.sh"
LIB_PY="${REPO_ROOT}/.claude/scripts/lib/jsonl_lock.py"

# ---- Pre-check: helper files exist ----
if [[ ! -f "${LIB_BASH}" ]]; then
  echo "[test-jsonl-append-race] FAIL: helper not found: ${LIB_BASH}" >&2
  exit 1
fi
if [[ ! -f "${LIB_PY}" ]]; then
  echo "[test-jsonl-append-race] FAIL: python helper not found: ${LIB_PY}" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "${LIB_BASH}"

# ---- Test 1: flag-on path — all 4 lines preserved + well-formed JSON ----
TARGET="${SANDBOX}/race-test.jsonl"
export CLAUDE_JSONL_APPEND_LOCK=on
: > "${TARGET}"
for i in 1 2 3 4; do
  ( jsonl_append_locked "${TARGET}" "{\"i\":${i}}" ) &
done
wait
LINES_ON=$(wc -l < "${TARGET}" | tr -d ' ')
if [[ "${LINES_ON}" -ne 4 ]]; then
  echo "[test-jsonl-append-race] FAIL: flag-on expected 4 lines, got ${LINES_ON}" >&2
  exit 1
fi
while IFS= read -r line; do
  if ! echo "${line}" | jq -e . >/dev/null 2>&1; then
    echo "[test-jsonl-append-race] FAIL: torn line under flag-on: ${line}" >&2
    exit 1
  fi
done < "${TARGET}"

# ---- Test 2: flag-off path — legacy direct append (byte-identical to previous behaviour) ----
unset CLAUDE_JSONL_APPEND_LOCK
: > "${TARGET}"
jsonl_append_locked "${TARGET}" '{"i":99}'
GOT=$(cat "${TARGET}")
if [[ "${GOT}" != '{"i":99}' ]]; then
  echo "[test-jsonl-append-race] FAIL: flag-off path produced unexpected content: ${GOT}" >&2
  exit 1
fi

# ---- Test 3: explicit off value behaves like unset ----
export CLAUDE_JSONL_APPEND_LOCK=off
: > "${TARGET}"
jsonl_append_locked "${TARGET}" '{"i":42}'
GOT=$(cat "${TARGET}")
if [[ "${GOT}" != '{"i":42}' ]]; then
  echo "[test-jsonl-append-race] FAIL: explicit off path produced unexpected content: ${GOT}" >&2
  exit 1
fi

# ---- Test 4: Python helper has matching contract ----
unset CLAUDE_JSONL_APPEND_LOCK
TARGET_PY="${SANDBOX}/race-test-py.jsonl"
: > "${TARGET_PY}"
python3 -c "
import sys
sys.path.insert(0, '${REPO_ROOT}/.claude/scripts/lib')
import jsonl_lock
jsonl_lock.jsonl_append_locked('${TARGET_PY}', '{\"py\":1}')
"
GOT_PY=$(cat "${TARGET_PY}")
if [[ "${GOT_PY}" != '{"py":1}' ]]; then
  echo "[test-jsonl-append-race] FAIL: python flag-off path produced unexpected content: ${GOT_PY}" >&2
  exit 1
fi

# ---- Test 5: Python flag-on parallel path preserves all lines ----
export CLAUDE_JSONL_APPEND_LOCK=on
: > "${TARGET_PY}"
python3 - <<PYEOF
import os, sys, threading
sys.path.insert(0, '${REPO_ROOT}/.claude/scripts/lib')
import jsonl_lock
def worker(i):
    jsonl_lock.jsonl_append_locked('${TARGET_PY}', '{"i":' + str(i) + '}')
threads = [threading.Thread(target=worker, args=(i,)) for i in range(1, 5)]
for t in threads: t.start()
for t in threads: t.join()
PYEOF
LINES_PY=$(wc -l < "${TARGET_PY}" | tr -d ' ')
if [[ "${LINES_PY}" -ne 4 ]]; then
  echo "[test-jsonl-append-race] FAIL: python flag-on expected 4 lines, got ${LINES_PY}" >&2
  exit 1
fi
while IFS= read -r line; do
  if ! echo "${line}" | jq -e . >/dev/null 2>&1; then
    echo "[test-jsonl-append-race] FAIL: torn line under python flag-on: ${line}" >&2
    exit 1
  fi
done < "${TARGET_PY}"

echo "[test-jsonl-append-race] PASS"
exit 0
