#!/usr/bin/env bash
# caveman-activate.sh
# Hook: SessionStart (matcher: empty/always)
# Purpose: Activate project-local caveman lite mode by emitting SKILL.md body
#          as additionalContext for the parent session.
#
# Modes:
#   lite (default) — emits SKILL.md body
#   off            — silent exit 0, no flag write, no context injection
#
# Resolution: CLAUDE_CAVEMAN_MODE env > flag file > 'lite'
# Sandbox: CLAUDE_WORKFLOW_STATE_DIR overrides default `.claude/workflow-state`
#
# Exit codes: always 0 (fail-silent — never block session start)

set -uo pipefail

# Resolve repo paths (CWD-independent)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/workflow-state}"
SKILL_FILE="${REPO_ROOT}/.claude/skills/caveman/SKILL.md"
FLAG_FILE="${STATE_DIR}/.caveman-mode"

# Drain stdin (SessionStart hook contract may send JSON payload; we don't need it)
_HOOK_INPUT=$(cat 2>/dev/null || true)
: "${_HOOK_INPUT}"  # silence unused warning

# Resolve mode
mode="${CLAUDE_CAVEMAN_MODE:-}"
if [[ -z "${mode}" && -f "${FLAG_FILE}" ]]; then
  mode=$(head -c 16 "${FLAG_FILE}" 2>/dev/null | tr -d '\n\r ' || echo "")
fi
mode="${mode:-lite}"

# Validate; fall back to default on mismatch
if ! [[ "${mode}" =~ ^(lite|off)$ ]]; then
  echo "[caveman-activate] WARN: invalid mode '${mode}' — falling back to 'lite'" >&2
  mode="lite"
fi

# Off-mode: silent exit
if [[ "${mode}" == "off" ]]; then
  exit 0
fi

# Best-effort atomic flag write — never block on failure
if mkdir -p "${STATE_DIR}" 2>/dev/null; then
  if tmp=$(mktemp "${STATE_DIR}/.caveman-mode.XXXXXX" 2>/dev/null); then
    if printf '%s' "${mode}" > "${tmp}" 2>/dev/null && mv "${tmp}" "${FLAG_FILE}" 2>/dev/null; then
      :  # success
    else
      rm -f "${tmp}" 2>/dev/null || true
      echo "[caveman-activate] WARN: flag file write failed at ${FLAG_FILE}" >&2
    fi
  fi
else
  echo "[caveman-activate] WARN: cannot create state dir ${STATE_DIR} — proceeding without flag write" >&2
fi

# Read SKILL.md body (strip YAML frontmatter)
if [[ -f "${SKILL_FILE}" ]]; then
  body=$(awk 'BEGIN{fm=0} /^---[[:space:]]*$/{fm++; next} fm>=2{print}' "${SKILL_FILE}" 2>/dev/null) || body=""
else
  echo "[caveman-activate] WARN: SKILL.md not found at ${SKILL_FILE} — emitting fallback ruleset" >&2
  body="Respond terse like smart caveman. All technical substance stay. Only fluff die.

Rules:
- Drop: articles (a/an/the) when meaning preserved; filler (just/really/basically); pleasantries; hedging
- Keep: complete sentences, technical terms exact, code blocks unchanged
- Pattern: [thing] [action] [reason]. [next step].

Boundaries (claude-kit): VERDICT: enum lines verbatim. VERDICT_JSON fenced blocks verbatim. \$handoff_contract / \$verdict_contract values verbatim. Markdown H2 headers verbatim. issue.problem inside verdict envelopes — complete sentences (canonical IDs depend on text stability). File paths exact. Part identifiers verbatim.

Stop: 'stop caveman' or 'normal mode'."
fi

# ── Pass body via env var, NOT chained redirection ──
# Why: `python3 - "${mode}" <<'PYEOF' <<<"${body}"` (the iter-1 form) chains
# two stdin redirections; bash's left-to-right rule means the here-string
# overrides the heredoc, so python3 receives BODY as stdin (no program text)
# and exits with SyntaxError. Passing values via environment keeps the heredoc
# as the sole stdin and lets the program read os.environ.
if command -v python3 >/dev/null 2>&1; then
  BODY="${body}" MODE="${mode}" python3 - <<'PYEOF'
import json, os
mode = os.environ["MODE"]
body = os.environ["BODY"]
out = {
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": f"[CAVEMAN MODE: {mode}]\n\n{body}",
    }
}
print(json.dumps(out, ensure_ascii=False))
PYEOF
else
  # Bash JSON-escape fallback (best-effort) — uses sed-based escape if python3 unavailable.
  esc=$(printf '%s' "${body}" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN{ORS="\\n"} {print}')
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[CAVEMAN MODE: %s]\\n\\n%s"}}\n' "${mode}" "${esc}"
fi

exit 0
