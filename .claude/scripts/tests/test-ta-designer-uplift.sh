#!/usr/bin/env bash
# test-ta-designer-uplift.sh — guards the TA-scout and designer parallel-EXPLORE
# mechanisms, plus the invariant that the retired role-critic panel stays retired.
# Exit code: 0 all pass, 1 any fail. rc=1 propagation; never `|| break`.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

TA="${REPO_ROOT}/.claude/skills/planner-rules/task-analysis.md"
DESIGNER="${REPO_ROOT}/.claude/commands/designer.md"
SETTINGS="${REPO_ROOT}/.claude/settings.json"
HOOKS="${REPO_ROOT}/.claude/hooks/hooks.json"
SUSPEND="${REPO_ROOT}/.claude/scripts/caveman-suspend-for-reviewer.sh"
SPEC_TMPL="${REPO_ROOT}/.claude/templates/spec-template.md"
DESIGN_SKILL="${REPO_ROOT}/.claude/skills/design-rules/SKILL.md"
METRICS="${REPO_ROOT}/.claude/skills/workflow-protocols/pipeline-metrics.md"
ROUTING="${REPO_ROOT}/.claude/rules/workflow.md"

rc=0; PASS=0; FAIL=0
ck() { # ck <label> <file> <ERE> — file MUST contain the pattern
  local label="$1" file="$2" pattern="$3"
  if [[ -f "${file}" ]] && grep -qiE -- "${pattern}" "${file}"; then
    echo "  PASS: ${label}"; PASS=$((PASS+1))
  else
    echo "  FAIL: ${label} — pattern '${pattern}' not in ${file##*/}"; FAIL=$((FAIL+1)); rc=1
  fi
}
nk() { # nk <label> <file> <ERE> — file MUST NOT contain the pattern; missing file is a FAIL
  local label="$1" file="$2" pattern="$3"
  if [[ ! -f "${file}" ]]; then
    echo "  FAIL: ${label} — ${file##*/} missing, absence unverifiable"; FAIL=$((FAIL+1)); rc=1
  elif grep -qiE -- "${pattern}" "${file}"; then
    echo "  FAIL: ${label} — retired pattern '${pattern}' present in ${file##*/}"; FAIL=$((FAIL+1)); rc=1
  else
    echo "  PASS: ${label}"; PASS=$((PASS+1))
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

echo "── B) designer parallel EXPLORE ──"
# designer.md already contains the bare word 'parallel_fanout' in prose ("NOT the
# parallel_fanout N-way path") — require the YAML KEY form that only the fan-out edit adds.
ck "parallel fan-out in EXPLORE"  "${DESIGNER}" '^[[:space:]]+parallel_fanout:'

echo "── C) role-critic panel stays retired (removal invariant) ──"
# The 5-role blind critic panel (Architect/Security/Ops-SRE/QA-Testability/Product-DX) was
# removed. Phase 3.5 is the single-context 7-lens pass again — that path is asserted
# positively at the end of this section and by test-design-critique-subphase.sh; everything
# panel-shaped must stay absent.
if [[ -e "${REPO_ROOT}/.claude/agents/design-critic.md" ]]; then
  echo "  FAIL: design-critic agent file is back"; FAIL=$((FAIL+1)); rc=1
else
  echo "  PASS: no design-critic agent file"; PASS=$((PASS+1))
fi
if [[ -e "${REPO_ROOT}/.claude/skills/design-rules/role-rubrics.md" ]]; then
  echo "  FAIL: role-rubrics.md is back"; FAIL=$((FAIL+1)); rc=1
else
  echo "  PASS: no role-rubrics.md"; PASS=$((PASS+1))
fi
nk "no 3.5a/3.5b sub-phases"      "${DESIGNER}"     '3\.5a|3\.5b'
nk "no critic dispatch"           "${DESIGNER}"     'design-critic|role-rubrics'
nk "no panel matcher in settings" "${SETTINGS}"     'design-critic'
nk "no panel matcher in hooks"    "${HOOKS}"        'design-critic'
nk "no critic in suspend hook"    "${SUSPEND}"      'design-critic'
nk "no panel block in spec tmpl"  "${SPEC_TMPL}"    '^[[:space:]]+panel:'
nk "no role field on finding"     "${SPEC_TMPL}"    '^[[:space:]]+role:'
nk "no panel metrics"             "${METRICS}"      'design_panel_metrics'
nk "no rubric load in skill"      "${DESIGN_SKILL}" 'role-rubrics'
nk "no critic routing row"        "${ROUTING}"      'design-critic'
# The retained layer: Phase 3.5 still runs the single-context lens pass.
ck "phase 3.5 loads lens set"     "${DESIGNER}"     'critique-lenses\.md'

echo "── D) caveman wiring count invariant ──"
n=$(grep -c 'caveman' "${SETTINGS}" 2>/dev/null) || true
if [[ "${n:-0}" -eq 5 ]]; then
  echo "  PASS: settings.json caveman count still exactly 5 (invariant — passes pre-change too)"; PASS=$((PASS+1))
else
  echo "  FAIL: settings.json caveman count = ${n:-0} (expected 5)"; FAIL=$((FAIL+1)); rc=1
fi

echo "── E) designer.md token ceiling (load-bearing per code-review CR-001) ──"
# Ceiling 2957 = the approved baseline 2275 tokens (o200k_base, commit a86dd0e) * 1.30 cap.
# Measured 2949 while the role panel shipped, 2327 after it was removed. The ceiling stays at
# the same policy value — it bounds the command body, it does not track it.
# A skipped check must NOT read as success (guard-fail-loudly).
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
