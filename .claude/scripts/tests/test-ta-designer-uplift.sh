#!/usr/bin/env bash
# test-ta-designer-uplift.sh — guards the TA-scout, designer parallel-EXPLORE,
# and role-panel (3.5a/3.5b) mechanisms plus their wiring invariants.
# Exit code: 0 all pass, 1 any fail. rc=1 propagation; never `|| break`.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

TA="${REPO_ROOT}/.claude/skills/planner-rules/task-analysis.md"
DESIGNER="${REPO_ROOT}/.claude/commands/designer.md"
RUBRICS="${REPO_ROOT}/.claude/skills/design-rules/role-rubrics.md"
CRITIC="${REPO_ROOT}/.claude/agents/design-critic.md"
SETTINGS="${REPO_ROOT}/.claude/settings.json"
SUSPEND="${REPO_ROOT}/.claude/scripts/caveman-suspend-for-reviewer.sh"
SPEC_TMPL="${REPO_ROOT}/.claude/templates/spec-template.md"

rc=0; PASS=0; FAIL=0
ck() { # ck <label> <file> <ERE>
  local label="$1" file="$2" pattern="$3"
  if [[ -f "${file}" ]] && grep -qiE -- "${pattern}" "${file}"; then
    echo "  PASS: ${label}"; PASS=$((PASS+1))
  else
    echo "  FAIL: ${label} — pattern '${pattern}' not in ${file##*/}"; FAIL=$((FAIL+1)); rc=1
  fi
}

echo "── A) TA-scout present (ceiling, fast path, output fields) ──"
ck "scout step present"        "${TA}" "Step 1\.5.*[Rr]econ|Bounded Recon"
ck "5-read ceiling"            "${TA}" "5 (targeted )?[Rr]eads?.*CEILING|CEILING.*not.*mandate"
# bare '0 reads' is a substring of the pre-existing '10/20/30 reads' planner budgets —
# anchor to the fast-path sentence that only the TA-scout section introduces.
ck "0-read fast path"          "${TA}" "classif(y|ies) at 0 reads"
ck "blast_radius output field" "${TA}" "blast_radius"
# bare 'evidence' matches pre-existing prose — anchor to the Output Format line.
ck "Evidence output line"      "${TA}" '^Evidence: \['
ck "confidence output field"   "${TA}" "confidence"

echo "── B) designer parallel EXPLORE + panel phases ──"
# designer.md:116 already contains the bare word 'parallel_fanout' in prose ("NOT the
# parallel_fanout N-way path") — require the YAML KEY form that only the fan-out edit adds.
ck "parallel fan-out in EXPLORE"  "${DESIGNER}" '^[[:space:]]+parallel_fanout:'
ck "phase 3.5a PANEL"             "${DESIGNER}" "3\.5a"
ck "phase 3.5b MERGE"             "${DESIGNER}" "3\.5b"
ck "blind round (no cross-talk)"  "${DESIGNER}" "blind"
ck "fallback to single-context"   "${DESIGNER}" "fallback.*single-context|single-context.*fallback"
ck "partial-panel >=2 rule"       "${DESIGNER}" ">= ?2|two or more"
ck "severity dampening"           "${DESIGNER}" "dampen"
ck "convergence warning"          "${DESIGNER}" "convergen"

echo "── C) lens-partition invariant: each of 7 lenses has exactly one role owner ──"
if [[ -f "${RUBRICS}" ]]; then
  for lens in "failure-mode" "hidden-assumption" "boundary" "misuse" "operability" "contract" "cost"; do
    n=$(grep -ciE "Owns:.*${lens}" "${RUBRICS}") || true
    if [[ "${n:-0}" -eq 1 ]]; then
      echo "  PASS: lens '${lens}' has exactly one owner"; PASS=$((PASS+1))
    else
      echo "  FAIL: lens '${lens}' owner count = ${n:-0} (expected 1)"; FAIL=$((FAIL+1)); rc=1
    fi
  done
  for role in "Architect" "Security" "Ops/SRE" "QA" "Product/DX"; do
    ck "role brief: ${role}" "${RUBRICS}" "## Role: .*${role}"
  done
else
  echo "  FAIL: role-rubrics.md missing (7 lens + 5 role checks unverifiable)"; FAIL=$((FAIL+1)); rc=1
fi

echo "── D) design-critic agent definition ──"
ck "agent file exists + name"  "${CRITIC}" "^name: design-critic"
ck "read-only toolset"         "${CRITIC}" "tools:"
# Gate on file existence — a missing file is FAIL, never a vacuous PASS.
if [[ ! -f "${CRITIC}" ]]; then
  echo "  FAIL: critic file missing — toolset safety unverifiable"; FAIL=$((FAIL+1)); rc=1
elif grep -qiE 'Write|Edit|Bash' <(sed -n '/^tools:/,/^[a-z]/p' "${CRITIC}"); then
  echo "  FAIL: critic toolset includes a write/exec tool"; FAIL=$((FAIL+1)); rc=1
else
  echo "  PASS: no write/exec tools in critic toolset"; PASS=$((PASS+1))
fi
ck "maxTurns bound"            "${CRITIC}" "^maxTurns: (8|9|10|11|12)$"
ck "memory scope"              "${CRITIC}" "^memory: project"
ck "routing row documented"    "${REPO_ROOT}/.claude/rules/workflow.md" "design-critic"

echo "── E) caveman wiring: count invariant + allowlist + matcher ──"
n=$(grep -c 'caveman' "${SETTINGS}" 2>/dev/null) || true
if [[ "${n:-0}" -eq 5 ]]; then
  echo "  PASS: settings.json caveman count still exactly 5 (invariant — passes pre-change too)"; PASS=$((PASS+1))
else
  echo "  FAIL: settings.json caveman count = ${n:-0} (expected 5)"; FAIL=$((FAIL+1)); rc=1
fi
ck "matcher covers design-critic"   "${SETTINGS}" "design-critic"
ck "suspend allowlist has critic"   "${SUSPEND}"  "design-critic"
# the pre-existing _HOOK_INPUT drain at :18 would match a 'HOOK_INPUT' pattern —
# guard on the NEW variable name that only the type-resolution edit introduces.
ck "suspend stdin resolution"       "${SUSPEND}"  "stdin_type"

echo "── F) spec-template additive panel fields ──"
ck "role field on finding"     "${SPEC_TMPL}" '^[[:space:]]+role:'
ck "panel sub-block"           "${SPEC_TMPL}" '^[[:space:]]+panel:'
ck "fallback_used field"       "${SPEC_TMPL}" "fallback_used"

echo "── G) designer.md token ceiling (load-bearing per code-review CR-001) ──"
# Ceiling 2957 = the approved baseline 2275 tokens (o200k_base, commit a86dd0e) * 1.30 plan cap.
# Measured 2949 at merge. A skipped check must NOT read as success (guard-fail-loudly).
SKIPPED=0
if command -v uv >/dev/null 2>&1; then
  dtok=$(DESIGNER="${DESIGNER}" uv run --quiet --with tiktoken python - <<'PYEOF' 2>/dev/null || echo ""
import os, tiktoken
print(len(tiktoken.get_encoding("o200k_base").encode(open(os.environ["DESIGNER"]).read())))
PYEOF
  )
  if [[ ! "${dtok}" =~ ^[0-9]+$ ]]; then
    echo "  SKIP: tiktoken unavailable — TOKEN CEILING NOT ENFORCED THIS RUN"; SKIPPED=$((SKIPPED+1))
  elif [[ "${dtok}" -le 2957 ]]; then
    echo "  PASS: designer.md ${dtok} tokens (<= 2957 ceiling, headroom $((2957-dtok)))"; PASS=$((PASS+1))
  else
    echo "  FAIL: designer.md ${dtok} tokens exceeds the 2957 ceiling (over by $((dtok-2957)))"
    echo "        The command body loads on EVERY /designer invocation. Trim prose or move"
    echo "        content to a just-in-time file — do not raise the ceiling."
    FAIL=$((FAIL+1)); rc=1
  fi
else
  echo "  SKIP: uv not installed — TOKEN CEILING NOT ENFORCED THIS RUN"; SKIPPED=$((SKIPPED+1))
fi

summary="─── ta-designer-uplift guard: ${PASS} passed, ${FAIL} failed"
if [[ "${SKIPPED}" -gt 0 ]]; then summary="${summary}, ${SKIPPED} SKIPPED (token ceiling NOT enforced)"; fi
echo "${summary} ───"
exit ${rc}
