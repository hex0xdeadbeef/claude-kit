#!/usr/bin/env bash
# test-designer-phase-invocation.sh
#
# Invariant: Phase 0.7 must be invocable, exclusive, and its absence must be loud —
# without halting runs that legitimately have no spec.
#
# Regression guard for the defect where an L/XL /workflow run marked Phase 0.7 complete
# without ever invoking /designer: it wrote its own design draft, dispatched five ad-hoc
# general-purpose "critic" subagents, produced no {feature}-spec.md, and nothing objected.
#
#   1. INVOCABLE  - workflow.md and orchestration-core.md name the tool that runs /designer.
#   2. EXCLUSIVE  - the orchestrator may not substitute its own design activity, and past
#                   artifacts under .claude/prompts/ are not doctrine.
#   3. DETECTED   - the spec check lives OUTSIDE designer_delegation, so a delegation that
#                   never happened is still caught, and it is FATAL on the L/XL route.
#   4. NOT OVER-EAGER - the gate exempts runs that legitimately have no spec (re-routed
#                   M->L, explicit user waiver), and standalone /planner is not aborted.
#
# Block extraction uses "start marker, stop at next sibling key" ranges rather than naming
# the following key, so reordering a block cannot silently widen a range to EOF.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }

WF=".claude/commands/workflow.md"
PL=".claude/commands/planner.md"
DS=".claude/commands/designer.md"
OC=".claude/skills/workflow-protocols/orchestration-core.md"
CL=".claude/skills/design-rules/critique-lenses.md"
CP=".claude/skills/workflow-protocols/checkpoint-protocol.md"

rc=0; NPASS=0; NFAIL=0
fail(){ echo "FAIL: $1"; rc=1; NFAIL=$((NFAIL+1)); }
pass(){ echo "PASS: $1"; NPASS=$((NPASS+1)); }

for f in "$WF" "$PL" "$DS" "$OC" "$CL" "$CP"; do
  [ -f "$f" ] || { echo "FAIL: required file missing: $f"; exit 1; }
done

# Extract a startup step by number, stopping at the NEXT step regardless of its number.
step_block(){ awk -v s="    - step: $1" '$0==s{f=1;next} f && /^    - step: /{exit} f' "$WF"; }
# Extract a 2-space-indented key under pipeline:/delegation_protocol:, stopping at the next sibling.
key_block(){ awk -v k="$1" 'BEGIN{re="^  " k ":"} $0 ~ re {f=1;next} f && /^  [a-z_]+:/{exit} f' "$WF"; }

STEP02="$(step_block '0.2')"
GATE="$(key_block 'spec_gate')"
DELEG="$(key_block 'designer_delegation')"
MAND="$(key_block 'mandatory')"

# -- 1. INVOCABLE ------------------------------------------------------------

if printf '%s\n' "$STEP02" | grep -q 'mechanism: "Skill tool'; then
  pass "DPI-1 startup step 0.2 names the Skill tool mechanism"
else
  fail "DPI-1 startup step 0.2 has no Skill-tool mechanism - Phase 0.7 has no executable verb"
fi

if printf '%s\n' "$DELEG" | grep -q '^    mechanism:.*Skill tool'; then
  pass "DPI-2 designer_delegation has its own Skill-tool mechanism key"
else
  fail "DPI-2 designer_delegation has no mechanism key - falls through to agent auto-delegation"
fi

if grep -q 'Phase 0\.7 . Design' "$OC" && grep -qi 'Skill tool by name' "$OC"; then
  pass "DPI-3 orchestration-core Phase 0.7 names the Skill tool"
else
  fail "DPI-3 orchestration-core Phase 0.7 still says only 'Execute /designer'"
fi

# -- 2. EXCLUSIVE ------------------------------------------------------------

if printf '%s\n' "$STEP02" | grep -qi 'does NOT dispatch critic subagents'; then
  pass "DPI-4 step 0.2 forbids ad-hoc critic subagents"
else
  fail "DPI-4 step 0.2 does not forbid ad-hoc critic subagents"
fi

if printf '%s\n' "$DELEG" | grep -q '^    pre_delegation:'; then
  pass "DPI-5 designer_delegation has pre_delegation"
else
  fail "DPI-5 designer_delegation has no pre_delegation block"
fi

# DPI-6: design-rules must be named inside the mandatory skill list specifically -
# a passing mention elsewhere in the file must not satisfy this.
if printf '%s\n' "$MAND" | grep -q '^    - Designer: design-rules'; then
  pass "DPI-6 design-rules is named in pipeline.mandatory"
else
  fail "DPI-6 design-rules absent from the pipeline.mandatory block"
fi

# DPI-7/DPI-8 assert the rule BODIES, not just their labels.
if grep -q 'Named executor' "$WF" && grep -q 'NEVER substitutes' "$WF" && grep -q 'no ad-hoc critic panels' "$WF"; then
  pass "DPI-7 named-executor rule states the prohibition, not just the label"
else
  fail "DPI-7 named-executor rule missing or gutted to its label"
fi

if grep -q 'Artifacts are evidence, not doctrine' "$WF" && grep -q 'never define what this pipeline prescribes' "$WF"; then
  pass "DPI-8 prior-artifact rule states the prohibition, not just the label"
else
  fail "DPI-8 prior-artifact rule missing or gutted to its label"
fi

# DPI-8b: the same conflation that caused the bug must stay corrected at the block level.
if grep -q 'mechanism_scope:' "$WF" && grep -q 'Applies to AGENTS only' "$WF"; then
  pass "DPI-8b delegation_protocol.mechanism is explicitly scoped to agents"
else
  fail "DPI-8b block-level mechanism is unscoped - it implicitly covers slash commands again"
fi

# -- 3. DETECTED -------------------------------------------------------------

GATE_LN="$(grep -n '^  spec_gate:' "$WF" | head -n1 | cut -d: -f1)"
DELEG_LN="$(grep -n '^delegation_protocol:' "$WF" | head -n1 | cut -d: -f1)"
if [ -n "$GATE_LN" ] && [ -n "$DELEG_LN" ] && [ "$GATE_LN" -lt "$DELEG_LN" ]; then
  pass "DPI-9 spec_gate exists outside delegation_protocol (line $GATE_LN < $DELEG_LN)"
else
  fail "DPI-9 spec_gate missing, or nested inside delegation_protocol (gate=${GATE_LN:-none} deleg=${DELEG_LN:-none})"
fi

if printf '%s\n' "$GATE" | grep -q 'FATAL' && printf '%s\n' "$GATE" | grep -q 'Do NOT start /planner'; then
  pass "DPI-10 spec_gate is FATAL and blocks /planner (assertion scoped to the spec_gate block)"
else
  fail "DPI-10 spec_gate does not stop the run on a missing L/XL spec"
fi

if grep -q '\[planner\] FATAL: L/XL task has no approved design spec' "$PL"; then
  pass "DPI-11 planner gates the orchestrated L/XL route on the spec"
else
  fail "DPI-11 planner still proceeds without a spec on the orchestrated L/XL route"
fi

# -- 4. NOT OVER-EAGER (regression guards for the false-FATAL flows) ----------

# DPI-14: an M->L re-route legitimately has no spec and must not be halted.
if printf '%s\n' "$GATE" | grep -q 're_routing.occurred: true' \
   && printf '%s\n' "$GATE" | grep -q 're_routing.phase is plan-review or implementation'; then
  pass "DPI-14 spec_gate exempts re-routed M->L runs"
else
  fail "DPI-14 spec_gate would FATAL on a legitimate M->L re-route (re-routing.md triggers)"
fi

# DPI-15: an explicit user waiver must be honoured by the gate.
if printf '%s\n' "$GATE" | grep -q '^      - if: "Checkpoint has design_waived: true'; then
  pass "DPI-15 spec_gate honours an explicit design_waived"
else
  fail "DPI-15 spec_gate ignores design_waived - the waiver is unreachable"
fi

# DPI-16: the waiver must be a READABLE canonical field, not prose in one command file.
if grep -q '^    design_waived:' "$CP"; then
  pass "DPI-16 design_waived is a canonical checkpoint field"
else
  fail "DPI-16 design_waived absent from checkpoint-protocol.md - waiver is write-only again"
fi

# DPI-17: standalone /planner must WARN, not abort - FATAL there was a regression.
if grep -q '\[planner\] WARN: L/XL task has no design spec' "$PL" \
   && grep -q '^      caller_signal:' "$PL" \
   && grep -q 'commands run INSIDE' "$PL"; then
  pass "DPI-17 standalone /planner warns, and caller_signal defines how the caller is told apart"
else
  fail "DPI-17 standalone /planner aborts, or caller_signal is gone (severity split unimplementable)"
fi

# DPI-18: the M-optional path must be resolved with the user, not silently.
if printf '%s\n' "$GATE" | grep -q 'user ACCEPTED the optional designer' \
   && printf '%s\n' "$GATE" | grep -q 'Record the answer as design_waived: true'; then
  pass "DPI-18 M + accepted-optional-designer is resolved with the user and the answer recorded"
else
  fail "DPI-18 spec_gate leaves M + optional-designer undefined"
fi

# -- 5. Original-invariant regression locks ----------------------------------

if grep -qiE 'agent|subagent|dispatch|spawn|parallel' "$CL"; then
  fail "DPI-12 critique-lenses.md gained subagent/dispatch language - Phase 3.5 must stay in-context"
else
  pass "DPI-12 critique-lenses.md remains subagent-free (stability invariant - passes pre-change too)"
fi

LENSES="$(grep -cE '^[0-9]+\. \*\*' "$CL")"
if [ "$LENSES" -eq 7 ] && ! grep -qE '3\.5a|3\.5b' "$DS"; then
  pass "DPI-13 Phase 3.5 is a single 7-lens pass, lenses=$LENSES (stability invariant - passes pre-change too)"
else
  fail "DPI-13 lens count is $LENSES (expected 7) or panel sub-phases reappeared in designer.md"
fi


# DPI-19: branch ORDER is load-bearing and must be locked. Existence checks alone let the
# regression return: moving the exemptions BELOW the FATAL branches restores the M->L false
# FATAL, and moving the usable-spec branch below the exemptions silently drops the --spec
# handoff on a re-routed re-plan. Both are position bugs no grep-for-presence can see.
ln_of(){ grep -n "$1" "$WF" | head -n1 | cut -d: -f1; }
SPEC_LN="$(ln_of '      - if: "An approved spec exists at')"
WAIVE_LN="$(ln_of '      - if: "Checkpoint has design_waived: true')"
REROUTE_LN="$(ln_of '      - if: "Checkpoint has re_routing.occurred: true')"
FATAL_LN="$(ln_of '      - if: "Complexity is L or XL AND the spec file is missing"')"
SM_LN="$(ln_of '      - if: "Complexity is S or M AND the designer was never requested"')"
if [ -n "$SPEC_LN" ] && [ -n "$WAIVE_LN" ] && [ -n "$REROUTE_LN" ] && [ -n "$FATAL_LN" ] && [ -n "$SM_LN" ] \
   && [ "$SPEC_LN" -lt "$SM_LN" ] \
   && [ "$SPEC_LN" -lt "$WAIVE_LN" ] && [ "$SPEC_LN" -lt "$REROUTE_LN" ] \
   && [ "$WAIVE_LN" -lt "$FATAL_LN" ] && [ "$REROUTE_LN" -lt "$FATAL_LN" ]; then
  pass "DPI-19 branch order holds: usable-spec($SPEC_LN) < exemptions($WAIVE_LN,$REROUTE_LN) < FATAL($FATAL_LN)"
else
  fail "DPI-19 spec_gate branch order broken (spec=${SPEC_LN:-none} waive=${WAIVE_LN:-none} reroute=${REROUTE_LN:-none} fatal=${FATAL_LN:-none})"
fi

# DPI-20: first-match-wins must be stated - the branches conflict by design, so an
# unordered reading of the list is ambiguous.
if printf '%s\n' "$GATE" | grep -q 'FIRST MATCH WINS'; then
  pass "DPI-20 spec_gate declares first-match-wins evaluation"
else
  fail "DPI-20 spec_gate branch list has no stated evaluation order"
fi

# DPI-21: spec freshness must stay WARN. Reclassifying a stale-looking spec as missing would
# FATAL every --from-phase 1 resume, because phase_completed is overwritten by Phase 1.
if printf '%s\n' "$GATE" | grep -q 'WARN, never FATAL' \
   && printf '%s\n' "$GATE" | grep -q 'Do NOT reclassify it as'; then
  pass "DPI-21 spec freshness is a WARN, not a reclassification to missing"
else
  fail "DPI-21 spec freshness would FATAL a valid --from-phase 1 resume"
fi

# DPI-22: spec_artifact must be a real durable field, not prose - it is the only record
# that survives Phase 1 overwriting phase_completed.
if grep -q '^    spec_artifact:' "$CP" && grep -q 'spec_artifact=' "$WF"; then
  pass "DPI-22 spec_artifact is a canonical checkpoint field and is written at Phase 0.7"
else
  fail "DPI-22 spec_artifact missing from checkpoint-protocol.md or never written"
fi


# DPI-23: the two gates must agree. planner.md self-describes as mirroring workflow.md's
# spec_gate, so a predicate that drifts between them silently produces contradictory outcomes
# on the same checkpoint state - an orchestrated run cleared by the gate then dead-ending in
# /planner, or vice versa. This check exists because exactly that drift shipped undetected:
# workflow.md was re-keyed onto re_routing.phase while planner.md kept original_route.
if grep -q 're_routing.phase is plan-review or implementation' "$WF" \
   && grep -q 're_routing.phase is plan-review or implementation' "$PL"; then
  pass "DPI-23 workflow.md and planner.md share the re-route exemption predicate"
else
  fail "DPI-23 spec_gate and planner step 0.5 disagree on the re-route exemption predicate"
fi

# DPI-24: original_route must never be used as a gate predicate anywhere. There is no canonical
# complexity-to-route mapping in the kit, and its own worked example pairs Complexity L with
# Route standard (task-analysis.md Example 2), so route values cannot identify an S/M origin.
# Mentions inside an explanatory "do NOT use this" rationale are allowed; a bare predicate is not.
if grep -nE 'original_route (is|minimal)' "$WF" "$PL" | grep -qv 'NOT on original_route\|NOT key'; then
  fail "DPI-24 original_route is used as a gate predicate - it cannot identify an S/M origin"
else
  pass "DPI-24 no gate keys on original_route"
fi

echo "INFO: $((NPASS+NFAIL)) checks evaluated, ${NPASS} passed, ${NFAIL} failed, 0 skipped"
[ "$rc" -eq 0 ] && echo "ALL PASS: test-designer-phase-invocation" || echo "SOME FAILED: test-designer-phase-invocation"
exit "$rc"
