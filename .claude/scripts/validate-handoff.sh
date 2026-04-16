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
VALIDATION_LOG="${REPO_ROOT}/.claude/workflow-state/handoff-validation.jsonl"
MODE_HANDOFF="${CLAUDE_HANDOFF_VALIDATION_MODE:-warn}"
MODE_VERDICT="${CLAUDE_VERDICT_VALIDATION_MODE:-warn}"

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
    MODE="${MODE_VERDICT}"
  elif [[ "${_jq_rc}" -ne 0 ]]; then
    echo "[validate-handoff] WARN: jq failed (rc=${_jq_rc}) to read \$verdict_contract from ${HANDOFF_FILE} — defaulting to handoff kind" >&2
  else
    # Neither $verdict_contract nor $handoff_contract discriminator is a guaranteed
    # signal here — check handoff side too. If BOTH are absent, the file is an
    # ambiguous payload that the schema's oneOf will reject. Fail-closed on ambiguity
    # when EITHER mode is strict: prevents a malformed record from sneaking past a
    # strict-mode caller just because the default-handoff fallback uses warn.
    _handoff_disc=$(jq -r '.["$handoff_contract"] // empty' "${HANDOFF_FILE}" 2>/dev/null)
    if [[ -z "${_handoff_disc}" ]]; then
      RECORD_KIND="unknown"
      if [[ "${MODE_HANDOFF}" == "strict" || "${MODE_VERDICT}" == "strict" ]]; then
        MODE="strict"
      fi
    fi
  fi
fi

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
  echo "[validate-handoff] WARN: neither check-jsonschema nor pipx found." \
       "Run: brew install pipx && pipx install 'check-jsonschema==0.37.*'" >&2
  exit 0
fi

# ─── Run validation ─────────────────────────────────────────────────────────────
VALIDATION_RC=0
VALIDATION_OUTPUT=$("${VALIDATOR_CMD[@]}" \
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
echo "${LOG_ENTRY}" >> "${VALIDATION_LOG}" 2>/dev/null || true

# ─── Return result ───────────────────────────────────────────────────────────────
if [[ "${VALIDATION_RC}" -eq 0 ]]; then
  echo "[validate-handoff] PASS: ${HANDOFF_FILE}" >&2
  exit 0
fi

# Validation failed — report errors
echo "[validate-handoff] FAIL: ${HANDOFF_FILE}" >&2
echo "${VALIDATION_OUTPUT}" >&2

if [[ "${MODE}" == "strict" ]]; then
  echo "[validate-handoff] BLOCKING (strict mode) — fix the handoff payload and retry" >&2
  exit 2
fi

# warn mode: log failure but do not block
echo "[validate-handoff] WARN (warn-mode): validation failed — set CLAUDE_HANDOFF_VALIDATION_MODE=strict to block" >&2
exit 0
