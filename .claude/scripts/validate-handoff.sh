#!/usr/bin/env bash
# validate-handoff.sh
# Hook: PostToolUse (Write|Edit .claude/workflow-state/*-handoff.json)
# Purpose: Validate handoff JSON against .claude/schemas/handoff.schema.json
#
# Modes:
#   Hook mode  (no args): file_path read from stdin JSON {tool_input:{file_path:"..."}}
#   Direct mode (1 arg):  file path provided as $1 — used in tests and manual runs
#
# Exit codes:
#   0 — pass or warn-mode (never blocks in warn-mode)
#   2 — validation FAIL in strict mode (CLAUDE_HANDOFF_VALIDATION_MODE=strict)
#   1 — internal error (missing jq, missing arg, bad state)
#
# Env:
#   CLAUDE_HANDOFF_VALIDATION_MODE  warn (default) | strict
#
# Dependencies: jq (required), check-jsonschema or pipx (required for validation)

set -uo pipefail

# ─── Resolve paths ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCHEMA_FILE="${REPO_ROOT}/.claude/schemas/handoff.schema.json"
# Part 1 / P1: honor CLAUDE_WORKFLOW_STATE_DIR for log paths so test sandboxes
# don't pollute the production log. Fallback preserves legacy hook-mode behavior
# (env unset → identical to pre-P1 path).
WORKFLOW_STATE_DIR_RESOLVED="${CLAUDE_WORKFLOW_STATE_DIR:-${REPO_ROOT}/.claude/workflow-state}"
mkdir -p "${WORKFLOW_STATE_DIR_RESOLVED}" 2>/dev/null || true
VALIDATION_LOG="${WORKFLOW_STATE_DIR_RESOLVED}/handoff-validation.jsonl"
MODE_HANDOFF="${CLAUDE_HANDOFF_VALIDATION_MODE:-warn}"
MODE_VERDICT="${CLAUDE_VERDICT_VALIDATION_MODE:-warn}"
MODE_ISSUE_ID="${CLAUDE_ISSUE_ID_VALIDATION_MODE:-warn}"

# ─── Get file path (dual-mode) ──────────────────────────────────────────────────
DIRECT_MODE=0
if [[ $# -gt 0 ]]; then
  # Direct mode: path provided as argument — filename guard skipped (caller controls file)
  DIRECT_MODE=1
  HANDOFF_FILE="$1"
else
  # Hook mode: parse stdin JSON
  if ! command -v jq &>/dev/null; then
    echo "[validate-handoff] ERROR: jq is required but not found in PATH" >&2
    exit 1
  fi
  STDIN_INPUT=$(cat)
  HANDOFF_FILE=$(echo "${STDIN_INPUT}" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
fi

# ─── Guard: skip if no file path resolved ──────────────────────────────────────
if [[ -z "${HANDOFF_FILE:-}" ]]; then
  echo "[validate-handoff] SKIP: no file path resolved" >&2
  exit 0
fi

# ─── Guard: ensure the file is actually a *-handoff.json (hook mode only) ──────
# In direct mode the caller explicitly specifies the file — skip this filter.
if [[ "${DIRECT_MODE}" -eq 0 && "${HANDOFF_FILE}" != *-handoff.json ]]; then
  exit 0
fi

# ─── Guard: file must exist ─────────────────────────────────────────────────────
if [[ ! -f "${HANDOFF_FILE}" ]]; then
  echo "[validate-handoff] SKIP: file not found: ${HANDOFF_FILE}" >&2
  exit 0
fi

# ─── Detect record kind via discriminator field (IMP-02) ───────────────────────
# Default: "handoff" for legacy compatibility. If $verdict_contract is present,
# switch RECORD_KIND to "verdict" and MODE to MODE_VERDICT.
RECORD_KIND="handoff"
MODE="${MODE_HANDOFF}"
if command -v jq &>/dev/null; then
  # PR-006: capture jq exit code explicitly so we can emit a breadcrumb when the
  # discriminator read fails (e.g. malformed JSON that slipped past earlier guards).
  # Silent fall-through to "handoff" kind is safe but leaves no trace — the WARN
  # below gives the user one line to understand why strict-mode didn't engage.
  #
  # CR-004: bracket-index syntax .["$verdict_contract"] is REQUIRED — jq treats a
  # $-prefix in .$foo as a variable reference (attempting to deref a jq variable
  # named $foo), which errors out on an undefined variable. The bracket form is
  # the only way to read a JSON object key that begins with a literal '$'. Same
  # pattern mirrored on the handoff side (line below) — do not "simplify" either.
  _verdict_disc=$(jq -r '.["$verdict_contract"] // empty' "${HANDOFF_FILE}" 2>/dev/null)
  _jq_rc=$?
  if [[ "${_jq_rc}" -eq 0 && -n "${_verdict_disc}" ]]; then
    RECORD_KIND="verdict"
    # IMP-03: MODE_ISSUE_ID boosts verdict validation to strict when the id
    # pattern constraint must block. MODE_VERDICT OR MODE_ISSUE_ID = strict
    # means schema violations on the verdict record block the write.
    if [[ "${MODE_VERDICT}" == "strict" || "${MODE_ISSUE_ID}" == "strict" ]]; then
      MODE="strict"
    else
      MODE="${MODE_VERDICT}"
    fi
  elif [[ "${_jq_rc}" -ne 0 ]]; then
    echo "[validate-handoff] WARN: jq failed (rc=${_jq_rc}) to read \$verdict_contract from ${HANDOFF_FILE} — defaulting to handoff kind" >&2
  else                                                                  # nesting: open no-verdict-disc
    # Neither $verdict_contract nor $handoff_contract discriminator is a guaranteed
    # signal here — check handoff side too. If BOTH are absent, the file is an
    # ambiguous payload that the schema's oneOf will reject. Fail-closed on ambiguity
    # when EITHER mode is strict: prevents a malformed record from sneaking past a
    # strict-mode caller just because the default-handoff fallback uses warn.
    _handoff_disc=$(jq -r '.["$handoff_contract"] // empty' "${HANDOFF_FILE}" 2>/dev/null)
    if [[ -z "${_handoff_disc}" ]]; then                                # nesting: open both-disc-absent
      # Part 4 / P4 (iter 2): shape-detect verdict envelope before falling through.
      # All three keys must be present (verdict: string, issues: array, handoff: object) —
      # conservative match avoids false positives on partial shapes.
      _verdict_shape=$(jq -r '
        if (.verdict | type == "string")
           and (.issues | type == "array")
           and (.handoff | type == "object")
        then "yes" else "no" end
      ' "${HANDOFF_FILE}" 2>/dev/null)
      if [[ "${_verdict_shape}" == "yes" ]]; then                       # nesting: open shape-yes
        RECORD_KIND="verdict_no_discriminator"
      else                                                              # nesting: shape-no
        RECORD_KIND="unknown"
      fi                                                                # nesting: close shape if/else
      # Fail-closed mode promotion (existing logic preserved verbatim):
      if [[ "${MODE_HANDOFF}" == "strict" || "${MODE_VERDICT}" == "strict" || "${MODE_ISSUE_ID}" == "strict" ]]; then
        MODE="strict"
      fi
    fi                                                                  # nesting: close both-disc-absent
  fi                                                                    # nesting: close no-verdict-disc / verdict-disc-present
fi                                                                      # nesting: close jq-available

# ─── Guard: schema must exist ───────────────────────────────────────────────────
if [[ ! -f "${SCHEMA_FILE}" ]]; then
  echo "[validate-handoff] WARN: schema not found at ${SCHEMA_FILE} — validation skipped" >&2
  exit 0
fi

# ─── Resolve validator command ──────────────────────────────────────────────────
# Prefer direct install (fastest); fall back to pipx run (caches after first use)
if command -v check-jsonschema &>/dev/null; then
  VALIDATOR_CMD=(check-jsonschema)
elif command -v pipx &>/dev/null; then
  VALIDATOR_CMD=(pipx run --spec "check-jsonschema==0.37.*" check-jsonschema)
else
  echo "[validate-handoff] WARN: neither check-jsonschema nor pipx found — run: brew install pipx && pipx install 'check-jsonschema==0.37.*'" >&2
  exit 0
fi

# ─── Part 2 / P2: log rotation threshold + helper ──────────────────────────────
# Sanitize threshold: positive integer or fall back to default.
MAX_LINES_RAW="${CLAUDE_VALIDATION_LOG_MAX_LINES:-10000}"
if [[ ! "${MAX_LINES_RAW}" =~ ^[0-9]+$ ]] || [[ "${MAX_LINES_RAW}" -le 0 ]]; then
  MAX_LINES_RAW=10000
fi
MAX_LOG_LINES="${MAX_LINES_RAW}"

# rotate_if_oversized — best-effort single-archive rotation.
# Args:
#   $1 = log file path
#   $2 = max lines threshold (optional; defaults to MAX_LOG_LINES global)
#        — addresses PR-40d39d21 (iter 2): explicit param enables future
#        per-call thresholds (e.g. different rotation policy for .jsonl vs -detail.log)
#        without refactor.
# Behavior: if file exists and exceeds threshold, mv → ${file}.1 (overwriting prior archive).
# Failures (e.g. permission denied) are silently swallowed — rotation must NEVER block validation.
#
# RACE-WINDOW NOTE (PR-52bb42a0, iter 2):
#   Between `wc -l` (read) and `mv -f` (rename), another concurrent hook may append.
#   In the worst case: two processes both observe lines > threshold, both call mv -f;
#   the second mv overwrites the rotated .log.1 with a freshly-created (very short) log,
#   losing 1+ minute of entries from process A. Mitigation: rotation is infrequent
#   (~6 weeks at observed 5KB/h), and effects are bounded (lost lines, not corruption).
#   Acceptable per spec § Risk Register; flock-based locking is out-of-scope for v1.
rotate_if_oversized() {
  local logfile="$1"
  local threshold="${2:-${MAX_LOG_LINES}}"
  if [[ ! -f "${logfile}" ]]; then
    return 0
  fi
  local lines
  lines=$(wc -l < "${logfile}" 2>/dev/null || echo 0)
  if [[ "${lines}" -gt "${threshold}" ]]; then
    mv -f "${logfile}" "${logfile}.1" 2>/dev/null || true
  fi
}

# ─── Run validation ─────────────────────────────────────────────────────────────
VALIDATION_RC=0
# Part 3 / P3: --verbose surfaces all branch errors (no "N other errors hidden"
# suppression). Primary cause becomes greppable in detail.log.
VALIDATION_OUTPUT=$("${VALIDATOR_CMD[@]}" \
  --verbose \
  --schemafile "${SCHEMA_FILE}" \
  "${HANDOFF_FILE}" 2>&1) || VALIDATION_RC=$?

# ─── Log result ─────────────────────────────────────────────────────────────────
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
FEATURE=$(basename "${HANDOFF_FILE}" .json | sed 's/-handoff$//')
VALID_BOOL=$([ "${VALIDATION_RC}" -eq 0 ] && echo "true" || echo "false")
LOG_ENTRY="{\"timestamp\":\"${TIMESTAMP}\",\"feature\":\"${FEATURE}\","
LOG_ENTRY+="\"file\":\"${HANDOFF_FILE}\",\"valid\":${VALID_BOOL},"
LOG_ENTRY+="\"mode\":\"${MODE}\",\"rc\":${VALIDATION_RC},"
LOG_ENTRY+="\"record_kind\":\"${RECORD_KIND}\"}"
# Part 2 / P2: rotate before append to bound disk usage.
rotate_if_oversized "${VALIDATION_LOG}"
echo "${LOG_ENTRY}" >> "${VALIDATION_LOG}" 2>/dev/null || true

# ─── Return result ───────────────────────────────────────────────────────────────
if [[ "${VALIDATION_RC}" -eq 0 ]]; then
  echo "[validate-handoff] PASS: ${HANDOFF_FILE}" >&2
  exit 0
fi

# Validation failed — report errors
echo "[validate-handoff] FAIL: ${HANDOFF_FILE}" >&2

# Part 5 / P5: write JSONL entry to detail.log instead of raw multi-line text.
# Single line of valid JSON per failure → grep / jq filtering becomes possible.
DETAIL_LOG="${VALIDATION_LOG%.jsonl}-detail.log"
# UTF-8 NOTE (PR-481732af, iter 2): on macOS `cut -c` is byte-oriented (BSD cut).
# check-jsonschema output is ASCII-only (verified via inspection of all 1920 lines
# in handoff-validation-detail.log — no non-ASCII bytes), so multibyte truncation
# is a theoretical concern, not an observed defect. Acknowledged and accepted as-is
# for v1; if check-jsonschema upgrades to emit non-ASCII content, switch to
# `head -c 300 | iconv -c -f utf-8 -t utf-8` for byte-safe + codepoint-safe handling.
ERROR_SUMMARY=$(printf '%s\n' "${VALIDATION_OUTPUT}" \
  | tr '\n' ' ' \
  | tr -s ' ' \
  | cut -c1-300)
DETAIL_ENTRY=$(jq -n -c \
  --arg ts "${TIMESTAMP}" \
  --arg file "${HANDOFF_FILE}" \
  --arg kind "${RECORD_KIND}" \
  --argjson rc "${VALIDATION_RC}" \
  --arg summary "${ERROR_SUMMARY}" \
  --arg full "${VALIDATION_OUTPUT}" \
  '{timestamp: $ts, file: $file, record_kind: $kind, rc: $rc, error_summary: $summary, full_output: $full}' \
  2>/dev/null || echo "{}")
# Part 2 / P2: rotate detail.log before append.
rotate_if_oversized "${DETAIL_LOG}"
echo "${DETAIL_ENTRY}" >> "${DETAIL_LOG}" 2>/dev/null || true

if [[ "${MODE}" == "strict" ]]; then
  echo "[validate-handoff] BLOCKING: fix the handoff payload and retry (strict mode)" >&2
  exit 2
fi

# warn mode: log failure but do not block
echo "[validate-handoff] WARN: validation failed (warn-mode) — set CLAUDE_HANDOFF_VALIDATION_MODE=strict to block" >&2
exit 0
