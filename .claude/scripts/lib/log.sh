#!/usr/bin/env bash
# .claude/scripts/lib/log.sh
# Shared stderr logger for kit hook scripts (AD-1, Proposal J).
#
# Usage from a hook script:
#   # shellcheck source=lib/log.sh
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
#   log_stderr INFO  "message text"
#   log_stderr WARN  "explanation"
#   log_stderr FAIL  "details"
#
# Output format:
#   [<basename>][session=<short-sid>][eff=<level>] LABEL: <message>
#
# Where:
#   short-sid = first 8 chars of $CLAUDE_CODE_SESSION_ID (v2.1.132+ Bash subprocess env),
#               or the literal "unknown" when unset.
#   eff       = $CLAUDE_EFFORT (v2.1.133+ hook subprocess env),
#               or "unknown" when unset.
#
# Backwards-compatible: the trailing "LABEL: <message>" tail matches the existing
# stderr convention enforced by test-hook-stderr-format.sh. The additive prefix is
# new; pre-source dependency-fail stderr lines (jq-not-found, python3-not-found)
# MUST remain in the legacy "[<basename>] LABEL: <msg>" shape because log_stderr is
# not yet defined at those call sites — both shapes are valid per workflow.md.

# Caveman boundary: the literal tokens "session=" and "eff=" MUST be emitted verbatim;
# they are tag keys, not free-text prose, and the byte-stability of test-log-stderr-prefix.sh
# depends on it.

log_stderr() {
  local label="${1:-INFO}"
  shift || true
  local msg="$*"
  local sid="${CLAUDE_CODE_SESSION_ID:-}"
  local short_sid="unknown"
  if [[ -n "${sid}" ]]; then short_sid="${sid:0:8}"; fi
  local eff="${CLAUDE_EFFORT:-unknown}"
  local base
  base="$(basename "${0:-shell}" .sh 2>/dev/null || echo "shell")"
  echo "[${base}][session=${short_sid}][eff=${eff}] ${label}: ${msg}" >&2
  return 0
}
