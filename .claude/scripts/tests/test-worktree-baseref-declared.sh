#!/usr/bin/env bash
# RED then GREEN: verify worktree.baseRef is declared as "fresh" in settings.json.
# Part 1 step 1.1/1.2 of changelog-v2.1.121-141-uplift.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SETTINGS="${REPO_ROOT}/.claude/settings.json"

actual="$(jq -r '.worktree.baseRef // empty' "${SETTINGS}")"
if [[ "${actual}" != "fresh" ]]; then
  echo "[test-worktree-baseref-declared] FAIL: expected worktree.baseRef='fresh', got '${actual}'" >&2
  exit 1
fi
echo "[test-worktree-baseref-declared] PASS"
