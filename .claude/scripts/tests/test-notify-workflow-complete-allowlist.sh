#!/usr/bin/env bash
# Part 5 / Proposal H: env on + APPROVED checkpoint emits terminalSequence with only
# allowlisted OSC codes (0/1/2/9/99/777 + BEL). Verifies no CSI / OSC 8 / OSC 52 / OSC 1337.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/notify-workflow-complete.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

export CLAUDE_KIT_PHASE_COMPLETION_NOTIFY=on
export CLAUDE_WORKFLOW_STATE_DIR="${TMP}"

# Both unquoted and quoted-value fixtures must work (PR-007 quote-stripping)
cat > "${TMP}/01-approved-checkpoint.yaml" <<'YAML'
phase_completed: 5
verdict: APPROVED
YAML

out=$(bash "${SCRIPT}")
ts=$(echo "${out}" | jq -r '.hookSpecificOutput.terminalSequence // ""')
test -n "${ts}" || { echo "[test-notify-workflow-complete-allowlist] FAIL: no terminalSequence emitted" >&2; exit 1; }

# Verify allowlisted OSC prefix
echo "${ts}" | grep -qE $'^\x1b\\][0-9]' \
  || { echo "[test-notify-workflow-complete-allowlist] FAIL: no OSC prefix" >&2; exit 1; }

# Forbidden patterns (CSI, OSC 8 hyperlinks, OSC 52 clipboard, OSC 1337 iTerm)
if echo "${ts}" | grep -qE $'\x1b\\['; then echo "FAIL: CSI present" >&2; exit 1; fi
if echo "${ts}" | grep -qE $'^\x1b\\]8;'; then echo "FAIL: OSC 8 present" >&2; exit 1; fi
if echo "${ts}" | grep -qE $'^\x1b\\]52;'; then echo "FAIL: OSC 52 present" >&2; exit 1; fi
if echo "${ts}" | grep -qE $'^\x1b\\]1337;'; then echo "FAIL: OSC 1337 present" >&2; exit 1; fi

# Quoted-value fixture (PR-007)
cat > "${TMP}/02-approved-quoted-checkpoint.yaml" <<'YAML'
phase_completed: 5
verdict: "APPROVED"
YAML
rm "${TMP}/01-approved-checkpoint.yaml"  # only the quoted file remains as "latest"
sleep 0.1
out2=$(bash "${SCRIPT}")
ts2=$(echo "${out2}" | jq -r '.hookSpecificOutput.terminalSequence // ""')
test -n "${ts2}" || { echo "[test-notify-workflow-complete-allowlist] FAIL: quoted-form fixture produced no terminalSequence" >&2; exit 1; }

echo "[test-notify-workflow-complete-allowlist] PASS"
