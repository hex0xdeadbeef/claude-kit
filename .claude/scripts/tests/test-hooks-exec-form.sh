#!/usr/bin/env bash
# RED then GREEN: every type-command hook handler in settings.json must have an args field.
# Step 1.3/1.4 of changelog-v2.1.121-141-uplift.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SETTINGS="${REPO_ROOT}/.claude/settings.json"

all_have_args="$(jq '[.hooks | .. | objects | select(type=="object") | select(.type=="command") | has("args")] | all' "${SETTINGS}")"
if [[ "${all_have_args}" != "true" ]]; then
  missing="$(jq -r '.hooks | .. | objects | select(type=="object") | select(.type=="command") | select(has("args") | not) | .command' "${SETTINGS}")"
  echo "[test-hooks-exec-form] FAIL: handlers missing 'args':" >&2
  echo "${missing}" >&2
  exit 1
fi
echo "[test-hooks-exec-form] PASS"
